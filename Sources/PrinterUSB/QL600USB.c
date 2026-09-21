#include "QL600USB.h"
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

typedef IOUSBInterfaceInterface300 **USB;
static int fail(char *error, size_t capacity, const char *message, IOReturn code) {
  snprintf(error, capacity, "%s (0x%08x)", message, code);
  return -1;
}
static int read_status(USB usb, UInt8 pipe, uint8_t status[32], char *error, size_t cap) {
  size_t used = 0;
  int packets = 0;
  while (used < 32 && packets++ < 300) {
    UInt32 size = (UInt32)(32 - used);
    IOReturn result = (*usb)->ReadPipeTO(usb, pipe, status + used, &size, 3000, 3000);
    if (result != kIOReturnSuccess) return fail(error, cap, "No QL-600 status response", result);
    if (size == 0) usleep(10000);
    used += size;
  }
#ifdef QL600_DIAGNOSTICS
  fprintf(stderr, "Status:"); for (int i = 0; i < 32; i++) fprintf(stderr, " %02x", status[i]); fprintf(stderr, "\n");
#endif
  if (used != 32 || status[0] != 0x80 || status[1] != 0x20 || status[2] != 0x42 || status[3] != 0x34 || status[4] != 0x47)
    return fail(error, cap, "Invalid QL-600 status response", 0);
  return 0;
}
int ql600_transfer(const uint8_t *job, size_t length, uint8_t status[32], int *sent, char *error, size_t capacity) {
  *sent = 0;
  memset(status, 0, 32);
  io_iterator_t devices = 0, interfaces = 0;
  io_service_t service = 0;
  IOUSBDeviceInterface **device = NULL;
  USB usb = NULL;
  int opened = 0, result = -1;
  CFMutableDictionaryRef match = IOServiceMatching(kIOUSBDeviceClassName);
  int vendor = 0x04f9, product = 0x20c0;
  CFNumberRef v = CFNumberCreate(NULL, kCFNumberIntType, &vendor), p = CFNumberCreate(NULL, kCFNumberIntType, &product);
  CFDictionarySetValue(match, CFSTR(kUSBVendorID), v);
  CFDictionarySetValue(match, CFSTR(kUSBProductID), p);
  CFRelease(v); CFRelease(p);
  IOReturn code = IOServiceGetMatchingServices(kIOMainPortDefault, match, &devices);
  if (code != 0 || !(service = IOIteratorNext(devices))) { fail(error, capacity, "Connect and turn on the Brother QL-600", code); goto done; }
  io_service_t extra = IOIteratorNext(devices);
  if (extra) { IOObjectRelease(extra); fail(error, capacity, "Connect only one QL-600 for this session", 0); goto done; }
  IOCFPlugInInterface **plugin = NULL;
  SInt32 score = 0;
  code = IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
  if (code || !plugin) { fail(error, capacity, "Cannot open QL-600 USB service", code); goto done; }
  HRESULT query = (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&device);
  IODestroyPlugInInterface(plugin);
  if (query || !device) { fail(error, capacity, "Cannot access QL-600 USB device", query); goto done; }
  IOUSBFindInterfaceRequest request = { kIOUSBFindInterfaceDontCare, kIOUSBFindInterfaceDontCare, kIOUSBFindInterfaceDontCare, kIOUSBFindInterfaceDontCare };
  code = (*device)->CreateInterfaceIterator(device, &request, &interfaces);
  if (code) { fail(error, capacity, "Cannot find QL-600 USB interface", code); goto done; }
  io_service_t interface;
  UInt8 inPipe = 0, outPipe = 0;
  while ((interface = IOIteratorNext(interfaces))) {
    plugin = NULL;
    code = IOCreatePlugInInterfaceForService(interface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
    IOObjectRelease(interface);
    if (code || !plugin) continue;
    query = (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID300), (LPVOID *)&usb);
    IODestroyPlugInInterface(plugin);
    if (query || !usb) continue;
    code = (*usb)->USBInterfaceOpen(usb);
    if (code) { (*usb)->Release(usb); usb = NULL; continue; }
    opened = 1;
    UInt8 count = 0;
    (*usb)->GetNumEndpoints(usb, &count);
    for (UInt8 i = 1; i <= count; i++) {
      UInt8 direction, number, type, interval; UInt16 packet;
      if ((*usb)->GetPipeProperties(usb, i, &direction, &number, &type, &packet, &interval) == 0 && type == kUSBBulk) {
        if (direction == kUSBIn) inPipe = i;
        if (direction == kUSBOut) outPipe = i;
      }
    }
    if (inPipe && outPipe) break;
    (*usb)->USBInterfaceClose(usb); (*usb)->Release(usb); usb = NULL; opened = 0;
    inPipe = outPipe = 0;
  }
  if (!usb || !inPipe || !outPipe) { fail(error, capacity, "QL-600 is busy or its USB interface is unavailable", 0); goto done; }
  uint8_t requestStatus[] = { 0x1b, 0x69, 0x53 };
  code = (*usb)->WritePipeTO(usb, outPipe, requestStatus, sizeof(requestStatus), 3000, 3000);
  if (code) { fail(error, capacity, "Cannot request QL-600 status", code); goto done; }
  // Ignore old unsolicited notifications and use only this request's response.
  for (int i = 0; i < 16; i++) {
    if (read_status(usb, inPipe, status, error, capacity)) goto done;
    if (status[18] == 0) break;
  }
  if (status[18] != 0) { fail(error, capacity, "No current QL-600 status", 0); goto done; }
  if (!job || !length) { result = 0; goto done; }
  if (status[8] || status[9] || status[19] != 0) { fail(error, capacity, "QL-600 is not ready. Check its cover, cutter and roll", (status[8] << 8) | status[9]); goto done; }
  if (status[10] != 62 || status[11] != 0x0a || status[17] != 0) { fail(error, capacity, "Load a 62 mm continuous DK-22205 roll", status[10]); goto done; }
  *sent = 1;
  for (size_t offset = 0; offset < length;) {
    UInt32 size = (UInt32)((length - offset) > 4096 ? 4096 : length - offset);
    code = (*usb)->WritePipeTO(usb, outPipe, (void *)(job + offset), size, 5000, 5000);
    if (code) { fail(error, capacity, "QL-600 transfer stopped. Check the label before retrying", code); goto done; }
    offset += size;
  }
  int completed = 0;
  time_t deadline = time(NULL) + 45;
  while (time(NULL) < deadline) {
    if (read_status(usb, inPipe, status, error, capacity)) goto done;
    if (status[8] || status[9] || status[18] == 2) { fail(error, capacity, "QL-600 reported a print error. Check the label", (status[8] << 8) | status[9]); goto done; }
    if (status[18] == 1) completed = 1;
    if (completed && status[18] == 6 && status[19] == 0) {
      uint8_t resetMode[] = { 0x1b, 0x69, 0x61, 0xff };
      (*usb)->WritePipeTO(usb, outPipe, resetMode, sizeof(resetMode), 3000, 3000);
      result = 0; goto done;
    }
  }
  fail(error, capacity, "QL-600 did not confirm completion. Check the label", 0);
done:
  if (usb) { if (opened) (*usb)->USBInterfaceClose(usb); (*usb)->Release(usb); }
  if (device) (*device)->Release(device);
  if (service) IOObjectRelease(service);
  if (interfaces) IOObjectRelease(interfaces);
  if (devices) IOObjectRelease(devices);
  return result;
}
#ifdef QL600_PROBE
int main(void) {
  uint8_t status[32]; int sent; char error[256];
  int code = ql600_transfer(NULL, 0, status, &sent, error, sizeof(error));
  if (code) { puts(error); return 1; }
  printf("QL-600: errors=%02x/%02x media_width=%u media_type=%02x media_length=%u phase=%u\n", status[8], status[9], status[10], status[11], status[17], status[19]);
  return 0;
}
#endif
