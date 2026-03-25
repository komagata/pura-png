# pura-png

A pure Ruby PNG decoder/encoder with zero C extension dependencies.

Part of the **pura-*** series — pure Ruby image codec gems.

## Features

- Color types: Grayscale (0), RGB (2), Indexed (3), Grayscale+Alpha (4), RGBA (6)
- Bit depths: 1, 2, 4, 8, 16
- All 5 filter types: None, Sub, Up, Average, Paeth
- Zlib compression/decompression via Ruby stdlib
- Image resizing (bilinear / nearest-neighbor / fit / fill)
- No native extensions, no FFI, no external dependencies
- CLI tool included

## Installation

```bash
gem install pura-png
```

## Usage

```ruby
require "pura-png"

# Decode
image = Pura::Png.decode("photo.png")
image.width      #=> 800
image.height     #=> 600
image.pixels     #=> Raw RGB byte string
image.pixel_at(x, y) #=> [r, g, b]

# Encode
Pura::Png.encode(image, "output.png")

# Resize
thumb = image.resize(200, 200)
fitted = image.resize_fit(800, 600)
fill = image.resize_fill(200, 200)

# From raw pixels
image = Pura::Png::Image.new(width, height, rgb_pixels_string)
Pura::Png.encode(image, "output.png")
```

## CLI

```bash
pura-png decode input.png --info
pura-png decode input.png --out pixels.dat
pura-png encode input.dat --width W --height H --out output.png
pura-png resize input.png --width 200 --height 200 --out thumb.png
pura-png resize input.png --fit 800x600 --out fitted.png
```

## Benchmark

400×400 image, Ruby 4.0.2 + YJIT.

### Decode

| Decoder | Time | Notes |
|---------|------|-------|
| chunky_png (Ruby) | 59 ms | Uses Zlib C extension |
| ffmpeg (C) | 60 ms | C |
| **pura-png** | **111 ms** | Pure Ruby (uses Zlib C ext for compression) |

### Encode

| Encoder | Time | vs ffmpeg |
|---------|------|-----------|
| **pura-png** | **52 ms** | **0.8× — faster than ffmpeg!** |
| ffmpeg (C) | 61 ms | — |

pura-png is slower than chunky_png for decoding, but supports more color types and bit depths, and is part of the pura-\* ecosystem for seamless format conversion. Both use Ruby's built-in Zlib (a C extension) for compression.

## Why pure Ruby?

- **`gem install` and go** — no `brew install`, no `apt install`, no C compiler needed
- **Works everywhere Ruby works** — CRuby, ruby.wasm, JRuby, TruffleRuby
- **Full PNG support** — all color types and bit depths, not just 8-bit RGB/RGBA
- **Part of pura-\*** — convert between JPEG, PNG, BMP, GIF, TIFF, WebP seamlessly

## Related gems

| Gem | Format | Status |
|-----|--------|--------|
| [pura-jpeg](https://github.com/komagata/pura-jpeg) | JPEG | ✅ Available |
| **pura-png** | PNG | ✅ Available |
| [pura-bmp](https://github.com/komagata/pura-bmp) | BMP | ✅ Available |
| [pura-gif](https://github.com/komagata/pura-gif) | GIF | ✅ Available |
| [pura-tiff](https://github.com/komagata/pura-tiff) | TIFF | ✅ Available |
| [pura-ico](https://github.com/komagata/pura-ico) | ICO | ✅ Available |
| [pura-webp](https://github.com/komagata/pura-webp) | WebP | ✅ Available |
| [pura-image](https://github.com/komagata/pura-image) | All formats | ✅ Available |

## License

MIT
