# pura-png

A pure Ruby PNG decoder/encoder with zero C extension dependencies.

Part of the pura-* series alongside [pura-jpeg](https://github.com/komagata/pura-jpeg).

## Installation

```ruby
gem "pura-png"
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

## Supported PNG Features

- Color types: Grayscale (0), RGB (2), Indexed (3), Grayscale+Alpha (4), RGBA (6)
- Bit depths: 1, 2, 4, 8, 16
- All 5 filter types: None, Sub, Up, Average, Paeth
- Zlib compression/decompression via Ruby stdlib

## CLI

```bash
pura-png decode input.png --info
pura-png decode input.png --out pixels.dat
pura-png encode input.dat --width W --height H --out output.png
pura-png resize input.png --width 200 --height 200 --out thumb.png
pura-png resize input.png --fit 800x600 --out fitted.png
pura-png benchmark input.png
```

## License

MIT
