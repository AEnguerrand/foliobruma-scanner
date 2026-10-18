#define _POSIX_C_SOURCE 200809L
#include <libusb-1.0/libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static libusb_device_handle *handle;
static unsigned char input, output;
static int attempted;
static int transfer(unsigned char endpoint, unsigned char *data, int length) {
  int count = 0;
  int result = libusb_bulk_transfer(handle, endpoint, data, length, &count, 3000);
  if (result || count != length) {
    fprintf(stderr, "USB result=%d bytes=%d expected=%d\n", result, count, length);
    return -1;
  }
  return 0;
}
static int status(unsigned char value[32]) {
  // A status can span USB reads. Every read has a finite timeout.
  int used = 0;
  for (int reads = 0; used < 32 && reads < 32; reads++) {
    int count = 0;
    int result = libusb_bulk_transfer(handle, input, value + used, 32 - used, &count, 3000);
    if (result || count <= 0) return -1;
    used += count;
  }
  if (used != 32 || memcmp(value, "\x80\x20\x42\x34\x47", 5)) return -1;
  fprintf(stderr, "status=");
  for (int i = 0; i < 32; i++) fprintf(stderr, "%02x", value[i]);
  fprintf(stderr, "\n");
  return 0;
}
int main(int argc, char **argv) {
  if (argc != 2 || (strcmp(argv[1], "--status") && strcmp(argv[1], "--print-test"))) {
    fprintf(stderr, "Usage: ql600-probe --status | --print-test < label.raster\n"); return 1;
  }
  int printing = !strcmp(argv[1], "--print-test");
  unsigned char job[65536]; size_t length = 0;
  if (printing) {
    length = fread(job, 1, sizeof(job), stdin);
    if (ferror(stdin) || !feof(stdin) || length != (200 + 6 + 13 + 17 + 225 * 93 + 1) || job[length - 1] != 0x1a) {
      fprintf(stderr, "Invalid diagnostic raster\n"); return 1;
    }
  }
  libusb_context *context = NULL; libusb_device **devices = NULL;
  struct libusb_config_descriptor *config = NULL;
  int claimed = -1, result = 1, matches = 0;
  if (libusb_init(&context)) return 1;
  ssize_t count = libusb_get_device_list(context, &devices);
  if (count < 0) goto done;
  for (ssize_t i = 0; i < count; i++) {
    struct libusb_device_descriptor descriptor;
    if (libusb_get_device_descriptor(devices[i], &descriptor)) goto done;
    if (descriptor.idVendor == 0x04f9 && descriptor.idProduct == 0x20c0) {
      matches++;
      if (matches == 1 && libusb_open(devices[i], &handle)) goto done;
    }
  }
  if (matches != 1 || !handle) { fprintf(stderr, "Connect exactly one QL-600\n"); goto done; }
  if (libusb_get_active_config_descriptor(libusb_get_device(handle), &config)) goto done;
  for (int i = 0; i < config->bNumInterfaces && claimed < 0; i++) {
    // Use the current default alternate setting only. Do not reconfigure the device.
    const struct libusb_interface_descriptor *interface = &config->interface[i].altsetting[0];
    if (interface->bAlternateSetting != 0 || interface->bInterfaceClass != 7) continue;
    input = output = 0;
    for (int e = 0; e < interface->bNumEndpoints; e++) {
      const struct libusb_endpoint_descriptor *endpoint = &interface->endpoint[e];
      if ((endpoint->bmAttributes & 3) != LIBUSB_TRANSFER_TYPE_BULK) continue;
      if (endpoint->bEndpointAddress & LIBUSB_ENDPOINT_IN) input = endpoint->bEndpointAddress;
      else output = endpoint->bEndpointAddress;
    }
    if (!input || !output) continue;
    // Never detach a kernel driver or steal a device from CUPS.
    if (!libusb_claim_interface(handle, interface->bInterfaceNumber)) claimed = interface->bInterfaceNumber;
  }
  if (claimed < 0) { fprintf(stderr, "Printer busy, permission denied, or interface unavailable\n"); goto done; }
  unsigned char request[] = {0x1b, 0x69, 0x53}, value[32] = {0};
  if (transfer(output, request, sizeof(request))) goto done;
  for (int i = 0; i < 16; i++) {
    if (status(value)) goto done;
    if (value[18] == 0) break;
  }
  if (value[18] != 0) goto done;
  if (!printing) { result = 0; goto done; }
  if (value[8] || value[9] || value[19] || value[10] != 62 || value[11] != 0x0a || value[17]) {
    fprintf(stderr, "Not ready: load 62 mm continuous DK-22205; check cover and cutter\n"); goto done;
  }
  attempted = 1;
  fprintf(stderr, "Print transfer started. Check the physical label before any retry.\n");
  for (size_t offset = 0; offset < length;) {
    int chunk = length - offset > 4096 ? 4096 : (int)(length - offset);
    if (transfer(output, job + offset, chunk)) goto done;
    offset += chunk;
    fprintf(stderr, "raster_bytes_sent=%zu\n", offset);
  }
  struct timespec start, now;
  clock_gettime(CLOCK_MONOTONIC, &start);
  int completed = 0;
  do {
    if (status(value) || value[8] || value[9] || value[18] == 2) goto done;
    if (value[18] == 1) completed = 1;
    if (completed && value[18] == 6 && value[19] == 0) { result = 0; break; }
    clock_gettime(CLOCK_MONOTONIC, &now);
  } while (now.tv_sec - start.tv_sec < 45);
  if (!result) fprintf(stderr, "Completion and ready received. Inspect cut length and scan the QR.\n");
done:
  if (claimed >= 0) libusb_release_interface(handle, claimed);
  if (config) libusb_free_config_descriptor(config);
  if (handle) libusb_close(handle);
  if (devices) libusb_free_device_list(devices, 1);
  libusb_exit(context);
  if (result) fprintf(stderr, "result=%s\n", attempted ? "uncertain-check-label" : "no-raster-sent");
  return result ? (attempted ? 2 : 1) : 0;
}
