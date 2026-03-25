# frozen_string_literal: true

require "minitest/autorun"
require "zlib"
require_relative "../lib/pura-png"

class TestDecoder < Minitest::Test
  FIXTURE_DIR = File.join(__dir__, "fixtures")

  def setup
    generate_fixtures unless File.exist?(File.join(FIXTURE_DIR, "rgb_8bit.png"))
  end

  def test_decode_rgb_8bit
    image = Pura::Png.decode(File.join(FIXTURE_DIR, "rgb_8bit.png"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    assert_equal 4 * 4 * 3, image.pixels.bytesize
    # Top-left pixel should be red
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_grayscale_8bit
    image = Pura::Png.decode(File.join(FIXTURE_DIR, "gray_8bit.png"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    # Grayscale 128 -> RGB (128, 128, 128)
    r, g, b = image.pixel_at(0, 0)
    assert_equal 128, r
    assert_equal 128, g
    assert_equal 128, b
  end

  def test_decode_indexed
    image = Pura::Png.decode(File.join(FIXTURE_DIR, "indexed.png"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    # First pixel should be red (palette index 0 = red)
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_rgba_8bit
    image = Pura::Png.decode(File.join(FIXTURE_DIR, "rgba_8bit.png"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    assert_equal 4 * 4 * 3, image.pixels.bytesize
    # Alpha is stripped, RGB preserved
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_filter_none
    image = Pura::Png.decode(File.join(FIXTURE_DIR, "filter_none.png"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    # Gradient: x=3 -> r=255, y=0 -> g=0
    r, g, = image.pixel_at(3, 0)
    assert_equal 255, r
    assert_equal 0, g
  end

  def test_decode_filter_sub
    image = Pura::Png.decode(File.join(FIXTURE_DIR, "filter_sub.png"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    r, _g, _b = image.pixel_at(3, 0)
    assert_equal 255, r
  end

  def test_decode_filter_up
    image = Pura::Png.decode(File.join(FIXTURE_DIR, "filter_up.png"))
    assert_equal 4, image.width
    assert_equal 4, image.height
  end

  def test_decode_filter_average
    image = Pura::Png.decode(File.join(FIXTURE_DIR, "filter_average.png"))
    assert_equal 4, image.width
    assert_equal 4, image.height
  end

  def test_decode_filter_paeth
    image = Pura::Png.decode(File.join(FIXTURE_DIR, "filter_paeth.png"))
    assert_equal 4, image.width
    assert_equal 4, image.height
  end

  def test_decode_from_binary_data
    data = File.binread(File.join(FIXTURE_DIR, "rgb_8bit.png"))
    image = Pura::Png.decode(data)
    assert_equal 4, image.width
    assert_equal 4, image.height
  end

  def test_decode_grayscale_alpha
    image = Pura::Png.decode(File.join(FIXTURE_DIR, "gray_alpha.png"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    r, g, b = image.pixel_at(0, 0)
    assert_equal 200, r
    assert_equal 200, g
    assert_equal 200, b
  end

  private

  def generate_fixtures
    FileUtils.mkdir_p(FIXTURE_DIR)

    # RGB 8-bit: 4x4, first row red, second green, third blue, fourth white
    generate_rgb_8bit
    generate_grayscale_8bit
    generate_indexed
    generate_rgba_8bit
    generate_gray_alpha
    generate_filter_fixtures
  end

  def generate_rgb_8bit
    width = 4
    height = 4
    pixels = String.new(encoding: Encoding::BINARY)
    # Row 0: red
    4.times { pixels << [255, 0, 0].pack("C3") }
    # Row 1: green
    4.times { pixels << [0, 255, 0].pack("C3") }
    # Row 2: blue
    4.times { pixels << [0, 0, 255].pack("C3") }
    # Row 3: white
    4.times { pixels << [255, 255, 255].pack("C3") }

    write_png(File.join(FIXTURE_DIR, "rgb_8bit.png"), width, height, 8, 2, pixels, filter: 0)
  end

  def generate_grayscale_8bit
    width = 4
    height = 4
    pixels = String.new(encoding: Encoding::BINARY)
    height.times do
      width.times { pixels << [128].pack("C") }
    end
    write_png(File.join(FIXTURE_DIR, "gray_8bit.png"), width, height, 8, 0, pixels, filter: 0)
  end

  def generate_indexed
    width = 4
    height = 4
    palette = [255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255].pack("C*")
    pixels = String.new(encoding: Encoding::BINARY)
    # Row 0: index 0 (red)
    4.times { pixels << [0].pack("C") }
    # Row 1: index 1 (green)
    4.times { pixels << [1].pack("C") }
    # Row 2: index 2 (blue)
    4.times { pixels << [2].pack("C") }
    # Row 3: index 3 (white)
    4.times { pixels << [3].pack("C") }

    write_png(File.join(FIXTURE_DIR, "indexed.png"), width, height, 8, 3, pixels, filter: 0, palette: palette)
  end

  def generate_rgba_8bit
    width = 4
    height = 4
    pixels = String.new(encoding: Encoding::BINARY)
    # Row 0: red with full alpha
    4.times { pixels << [255, 0, 0, 255].pack("C4") }
    # Row 1: green with half alpha
    4.times { pixels << [0, 255, 0, 128].pack("C4") }
    # Row 2: blue
    4.times { pixels << [0, 0, 255, 255].pack("C4") }
    # Row 3: white
    4.times { pixels << [255, 255, 255, 255].pack("C4") }

    write_png(File.join(FIXTURE_DIR, "rgba_8bit.png"), width, height, 8, 6, pixels, filter: 0)
  end

  def generate_gray_alpha
    width = 4
    height = 4
    pixels = String.new(encoding: Encoding::BINARY)
    height.times do
      width.times { pixels << [200, 255].pack("C2") }
    end
    write_png(File.join(FIXTURE_DIR, "gray_alpha.png"), width, height, 8, 4, pixels, filter: 0)
  end

  def generate_filter_fixtures
    width = 4
    height = 4
    # Create gradient RGB pixels for meaningful filter testing
    pixels = String.new(encoding: Encoding::BINARY)
    height.times do |y|
      width.times do |x|
        r = (x * 85) & 0xFF # 0, 85, 170, 255
        g = (y * 85) & 0xFF
        b = ((x + y) * 42) & 0xFF
        pixels << [r, g, b].pack("C3")
      end
    end

    [0, 1, 2, 3, 4].each do |filter|
      name = %w[none sub up average paeth][filter]
      write_png(File.join(FIXTURE_DIR, "filter_#{name}.png"), width, height, 8, 2, pixels, filter: filter)
    end
  end

  def write_png(path, width, height, bit_depth, color_type, raw_pixels, filter: 0, palette: nil)
    # Compute scanline width based on color type and bit depth
    samples = case color_type
              when 0 then 1
              when 2 then 3
              when 3 then 1
              when 4 then 2
              when 6 then 4
              end
    bpp = samples # bytes per pixel for 8-bit
    scanline_bytes = width * samples * (bit_depth >= 8 ? bit_depth / 8 : 1)
    if bit_depth < 8
      pixels_per_byte = 8 / bit_depth
      scanline_bytes = ((width * samples) + pixels_per_byte - 1) / pixels_per_byte
    end

    # Build filtered data with specified filter type
    filtered = String.new(encoding: Encoding::BINARY)
    prev_row = [0] * scanline_bytes

    height.times do |y|
      row_start = y * scanline_bytes
      row = raw_pixels.byteslice(row_start, scanline_bytes).bytes

      filtered << filter.chr

      case filter
      when 0 # None
        row.each { |b| filtered << b.chr }
      when 1 # Sub
        row.each_with_index do |b, i|
          left = i >= bpp ? row[i - bpp] : 0
          filtered << ((b - left) & 0xFF).chr
        end
      when 2 # Up
        row.each_with_index do |b, i|
          filtered << ((b - prev_row[i]) & 0xFF).chr
        end
      when 3 # Average
        row.each_with_index do |b, i|
          left = i >= bpp ? row[i - bpp] : 0
          filtered << ((b - ((left + prev_row[i]) / 2)) & 0xFF).chr
        end
      when 4 # Paeth
        row.each_with_index do |b, i|
          left = i >= bpp ? row[i - bpp] : 0
          up = prev_row[i]
          up_left = i >= bpp ? prev_row[i - bpp] : 0
          filtered << ((b - paeth(left, up, up_left)) & 0xFF).chr
        end
      end

      prev_row = row
    end

    compressed = Zlib::Deflate.deflate(filtered)

    out = String.new(encoding: Encoding::BINARY)
    # Signature
    out << [137, 80, 78, 71, 13, 10, 26, 10].pack("C8")
    # IHDR
    ihdr = [width, height, bit_depth, color_type, 0, 0, 0].pack("NNC5")
    out << make_chunk("IHDR", ihdr)
    # PLTE (if indexed)
    out << make_chunk("PLTE", palette) if palette
    # IDAT
    out << make_chunk("IDAT", compressed)
    # IEND
    out << make_chunk("IEND", "")

    File.binwrite(path, out)
  end

  def make_chunk(type, data)
    data = data.b
    crc = Zlib.crc32(type + data)
    [data.bytesize].pack("N") + type + data + [crc].pack("N")
  end

  def paeth(a, b, c)
    p = a + b - c
    pa = (p - a).abs
    pb = (p - b).abs
    pc = (p - c).abs
    if pa <= pb && pa <= pc then a
    elsif pb <= pc then b
    else c
    end
  end
end
