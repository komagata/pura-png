# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/pura-png"

class TestEncoder < Minitest::Test
  TMP_DIR = File.join(__dir__, "tmp")

  def setup
    FileUtils.mkdir_p(TMP_DIR)
  end

  def teardown
    Dir.glob(File.join(TMP_DIR, "*")).each { |f| File.delete(f) }
    FileUtils.rm_f(TMP_DIR)
  end

  def test_encode_creates_valid_png
    image = create_red_image(8, 8)
    path = File.join(TMP_DIR, "test_output.png")
    size = Pura::Png.encode(image, path)
    assert size.positive?
    assert File.exist?(path)

    # Verify PNG signature
    data = File.binread(path)
    assert_equal [137, 80, 78, 71, 13, 10, 26, 10].pack("C8"), data.byteslice(0, 8)
  end

  def test_encode_decode_roundtrip
    image = create_gradient_image(16, 16)
    path = File.join(TMP_DIR, "roundtrip.png")
    Pura::Png.encode(image, path)

    decoded = Pura::Png.decode(path)
    assert_equal 16, decoded.width
    assert_equal 16, decoded.height
    assert_equal image.pixels, decoded.pixels
  end

  def test_encode_decode_roundtrip_solid_colors
    [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255], [0, 0, 0]].each do |color|
      pixels = color.pack("C3").b * (8 * 8)
      image = Pura::Png::Image.new(8, 8, pixels)
      path = File.join(TMP_DIR, "solid_#{color.join("_")}.png")
      Pura::Png.encode(image, path)

      decoded = Pura::Png.decode(path)
      r, g, b = decoded.pixel_at(4, 4)
      assert_equal color[0], r, "Red mismatch for #{color}"
      assert_equal color[1], g, "Green mismatch for #{color}"
      assert_equal color[2], b, "Blue mismatch for #{color}"
    end
  end

  def test_encode_with_compression_levels
    image = create_gradient_image(32, 32)

    sizes = [0, 1, 6, 9].map do |level|
      path = File.join(TMP_DIR, "compress_#{level}.png")
      Pura::Png.encode(image, path, compression: level)
      File.size(path)
    end

    # Higher compression should generally produce smaller files
    assert sizes[0] >= sizes[3], "Compression 0 should be >= compression 9"
  end

  def test_encode_preserves_pixel_data_exactly
    pixels = String.new(encoding: Encoding::BINARY)
    256.times do |i|
      pixels << [i, (i * 2) & 0xFF, (i * 3) & 0xFF].pack("C3")
    end
    image = Pura::Png::Image.new(16, 16, pixels)
    path = File.join(TMP_DIR, "exact_pixels.png")
    Pura::Png.encode(image, path)

    decoded = Pura::Png.decode(path)
    assert_equal pixels, decoded.pixels
  end

  def test_encode_various_sizes
    [[1, 1], [3, 5], [100, 1], [1, 100], [64, 64]].each do |w, h|
      pixels = "\x80\x80\x80".b * (w * h)
      image = Pura::Png::Image.new(w, h, pixels)
      path = File.join(TMP_DIR, "size_#{w}x#{h}.png")
      Pura::Png.encode(image, path)

      decoded = Pura::Png.decode(path)
      assert_equal w, decoded.width
      assert_equal h, decoded.height
      assert_equal pixels, decoded.pixels
    end
  end

  def test_encode_from_image_class
    image = Pura::Png::Image.new(2, 2, "\xFF\x00\x00\x00\xFF\x00\x00\x00\xFF\xFF\xFF\xFF".b)
    path = File.join(TMP_DIR, "from_image.png")
    Pura::Png.encode(image, path)

    decoded = Pura::Png.decode(path)
    assert_equal [255, 0, 0], decoded.pixel_at(0, 0)
    assert_equal [0, 255, 0], decoded.pixel_at(1, 0)
    assert_equal [0, 0, 255], decoded.pixel_at(0, 1)
    assert_equal [255, 255, 255], decoded.pixel_at(1, 1)
  end

  private

  def create_red_image(w, h)
    pixels = "\xFF\x00\x00".b * (w * h)
    Pura::Png::Image.new(w, h, pixels)
  end

  def create_gradient_image(w, h)
    pixels = String.new(encoding: Encoding::BINARY, capacity: w * h * 3)
    h.times do |y|
      w.times do |x|
        r = (x * 255 / [w - 1, 1].max)
        g = (y * 255 / [h - 1, 1].max)
        b = 128
        pixels << r.chr << g.chr << b.chr
      end
    end
    Pura::Png::Image.new(w, h, pixels)
  end
end
