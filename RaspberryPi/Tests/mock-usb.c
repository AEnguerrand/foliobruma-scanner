// Software-only USB fault tests. These do not use a USB device.
#include <libusb-1.0/libusb.h>
#include <stdlib.h>
#include <string.h>
static int reads;
static libusb_device *device_list[] = {(libusb_device *)1, NULL};
static const struct libusb_endpoint_descriptor endpoints[] = {
  {.bEndpointAddress = 0x81, .bmAttributes = 2}, {.bEndpointAddress = 0x02, .bmAttributes = 2}
};
static const struct libusb_interface_descriptor alternate = {
  .bInterfaceNumber = 0, .bAlternateSetting = 0, .bNumEndpoints = 2, .bInterfaceClass = 7, .endpoint = endpoints
};
static const struct libusb_interface interface = {.altsetting = &alternate, .num_altsetting = 1};
static struct libusb_config_descriptor config = {.bNumInterfaces = 1, .interface = &interface};
int LIBUSB_CALL libusb_init(libusb_context **ctx) { *ctx = (libusb_context *)1; return 0; }
void LIBUSB_CALL libusb_exit(libusb_context *ctx) { (void)ctx; }
ssize_t LIBUSB_CALL libusb_get_device_list(libusb_context *ctx, libusb_device ***list) { (void)ctx; *list = device_list; return 1; }
void LIBUSB_CALL libusb_free_device_list(libusb_device **list, int unref) { (void)list; (void)unref; }
int LIBUSB_CALL libusb_get_device_descriptor(libusb_device *dev, struct libusb_device_descriptor *desc) {
  (void)dev; memset(desc, 0, sizeof(*desc)); desc->idVendor = 0x04f9; desc->idProduct = 0x20c0; return 0;
}
int LIBUSB_CALL libusb_open(libusb_device *dev, libusb_device_handle **handle) { (void)dev; *handle = (libusb_device_handle *)1; return 0; }
void LIBUSB_CALL libusb_close(libusb_device_handle *handle) { (void)handle; }
libusb_device *LIBUSB_CALL libusb_get_device(libusb_device_handle *handle) { (void)handle; return (libusb_device *)1; }
int LIBUSB_CALL libusb_get_active_config_descriptor(libusb_device *dev, struct libusb_config_descriptor **out) { (void)dev; *out = &config; return 0; }
void LIBUSB_CALL libusb_free_config_descriptor(struct libusb_config_descriptor *desc) { (void)desc; }
int LIBUSB_CALL libusb_claim_interface(libusb_device_handle *handle, int number) { (void)handle; (void)number; return 0; }
int LIBUSB_CALL libusb_release_interface(libusb_device_handle *handle, int number) { (void)handle; (void)number; return 0; }
int LIBUSB_CALL libusb_bulk_transfer(libusb_device_handle *handle, unsigned char endpoint, unsigned char *data, int length, int *transferred, unsigned int timeout) {
  (void)handle; (void)timeout;
  const char *test = getenv("MOCK_USB");
  *transferred = length;
  if (endpoint == 0x02) {
    if (length > 3 && test && !strcmp(test, "partial")) { *transferred = 10; return LIBUSB_ERROR_TIMEOUT; }
    return 0;
  }
  if (test && !strcmp(test, "timeout")) { *transferred = 0; return LIBUSB_ERROR_TIMEOUT; }
  memset(data, 0, length);
  memcpy(data, "\x80\x20\x42\x34\x47", 5);
  data[10] = test && !strcmp(test, "roll") ? 29 : 62;
  data[11] = 0x0a;
  data[18] = reads == 0 ? 0 : reads == 1 ? 1 : 6;
  if (test && !strcmp(test, "invalid")) data[0] = 0;
  reads++;
  return 0;
}
