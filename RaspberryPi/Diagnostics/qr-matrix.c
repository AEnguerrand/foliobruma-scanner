#include <qrencode.h>
#include <stdio.h>

int main(void) {
  // Fixed public test data. This program makes no network request.
  QRcode *qr = QRcode_encodeString8bit("https://example.com/pi-test", 0, QR_ECLEVEL_M);
  if (!qr || qr->width > 33) { if (qr) QRcode_free(qr); return 1; }
  for (int y = 0; y < qr->width; y++) {
    for (int x = 0; x < qr->width; x++) putchar((qr->data[y * qr->width + x] & 1) ? '1' : '0');
    putchar('\n');
  }
  QRcode_free(qr);
  return ferror(stdout) ? 1 : 0;
}
