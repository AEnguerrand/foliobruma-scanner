#ifndef QL600_USB_H
#define QL600_USB_H
#include <stdint.h>
#include <stddef.h>
// Returns 0 on success. sent is set before any print bytes can reach the device.
int ql600_transfer(const uint8_t *job, size_t length, uint8_t status[32], int *sent, char *error, size_t capacity);
#endif
