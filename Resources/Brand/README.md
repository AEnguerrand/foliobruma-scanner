# Scanner identity

The selected identity uses old cream letters, a matte charcoal background, and
an ochre document camera. The wordmark uses clean sans-serif lettering.
The future SaaS can use the same colours and type style with a different symbol.

- `AppIcon.png`: source image for the macOS icon and app interface.
- `README-logo.png`: horizontal logo with the wordmark on a light background.
- `scan-setup.png`: README setup illustration with a Mac, document camera, paper,
  and optional USB button and label printer.
- `build.sh` creates the multi-resolution ICNS file with macOS tools.

These assets were prepared with built-in ImageGen. The wordmark is raster artwork;
it does not require a font installation and is not a claim to use a specific font.

Generation brief: keep the selected Quiet archive symbol, replace the serif
wordmark with a medium-weight humanist sans-serif, and keep the exact text
Foliobruma and SCANNER. Extract the icon onto transparency and the horizontal
wordmark onto an opaque light background. Preserve paper texture, colours, and
camera geometry. Do not add books, a wrapping camera arm, or glossy effects.

The setup illustration uses the same charcoal, cream, and ochre colours. It
shows generic equipment and blank paper, not a product photo or app screenshot.
The selected version has no simulated light beam and uses small headings.

## Public app screenshots and demo

- `app-review.png`: real English app interface with three synthetic sample pages.
- `app-review-fr.png`: the same review interface in French.
- `review-demo.gif`: silent, stepped walkthrough of page review and PDF export preparation.
  It uses real app screenshots held for a few seconds per step, not a continuous
  camera recording. It does not demonstrate live capture or capture timing.

The screenshots were prepared on 27 September 2026 from source commit
`4cbdc38` in an isolated demo app. The demo uses a separate bundle identifier, temporary
session storage, and generated garden notes. It does not load private sessions
or connect to an account. The production app source is unchanged.

Only the named public PNG and GIF files are exempt from the private-image Git
rules. Do not add private scans or screenshots of private document lists.
