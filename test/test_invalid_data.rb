# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "zlib"
require_relative "../lib/pura-png"

class TestInvalidData < Minitest::Test
  def test_rejects_invalid_crc
    data = png
    data.setbyte(29, data.getbyte(29) ^ 1)
    error = assert_raises(Pura::Png::DecodeError) { Pura::Png.decode(data) }
    assert_match(/CRC/, error.message)
  end

  def test_rejects_invalid_header_length
    error = assert_raises(Pura::Png::DecodeError) { Pura::Png.decode(png(header: "short")) }
    assert_match(/IHDR.*13/, error.message)
  end

  def test_rejects_invalid_dimensions_and_color_depth
    [[0, 1, 8, 2], [1, 1, 4, 2], [1, 1, 8, 5]].each do |values|
      header = [*values, 0, 0, 0].pack("NNC5")
      assert_raises(Pura::Png::DecodeError) { Pura::Png.decode(png(header: header)) }
    end
  end

  def test_checks_pixel_limit_before_decoding
    header = [40_000_001, 1, 8, 2, 0, 0, 0].pack("NNC5")
    error = assert_raises(Pura::Png::DecodeError) { Pura::Png.decode(png(header: header)) }
    assert_match(/pixel limit/, error.message)
  end

  def test_checks_input_limit_for_bytes_and_files
    data = png
    Dir.mktmpdir do |dir|
      path = File.join(dir, "image.png")
      File.binwrite(path, data)
      [data, path].each do |input|
        error = assert_raises(Pura::Png::DecodeError) { Pura::Png.decode(input, max_input_bytes: data.bytesize - 1) }
        assert_match(/input limit/, error.message)
      end
    end
  end

  def test_checks_configurable_pixel_and_decoded_limits
    header = [2, 1, 8, 2, 0, 0, 0].pack("NNC5")
    error = assert_raises(Pura::Png::DecodeError) { Pura::Png.decode(png(header: header), max_pixels: 1) }
    assert_match(/pixel limit/, error.message)
    error = assert_raises(Pura::Png::DecodeError) { Pura::Png.decode(png, max_decoded_bytes: 3) }
    assert_match(/decoded byte limit/, error.message)
  end

  def test_rejects_too_much_or_too_little_inflated_data
    ["\0".b, "\0".b * 100_000].each do |raw|
      error = assert_raises(Pura::Png::DecodeError) { Pura::Png.decode(png(raw: raw)) }
      assert_match(/scanline data/, error.message)
    end
  end

  def test_rejects_truncated_compressed_stream
    compressed = Zlib.deflate("\0\xFF\0\0".b)[0...-2]
    error = assert_raises(Pura::Png::DecodeError) { Pura::Png.decode(png(compressed: compressed)) }
    assert_match(/compressed data/, error.message)
  end

  def test_rejects_idat_before_ihdr
    data = Pura::Png::Decoder::PNG_SIGNATURE + chunk("IDAT", Zlib.deflate("\0\xFF\0\0".b)) +
           chunk("IHDR", default_header) + chunk("IEND", "")
    error = assert_raises(Pura::Png::DecodeError) { Pura::Png.decode(data) }
    assert_match(/IHDR.*first/, error.message)
  end

  private

  def default_header
    [1, 1, 8, 2, 0, 0, 0].pack("NNC5")
  end

  def png(header: default_header, raw: "\0\xFF\0\0".b, compressed: Zlib.deflate(raw))
    Pura::Png::Decoder::PNG_SIGNATURE + chunk("IHDR", header) + chunk("IDAT", compressed) + chunk("IEND", "")
  end

  def chunk(type, data)
    [data.bytesize].pack("N") + type.b + data.b + [Zlib.crc32(type.b + data.b)].pack("N")
  end
end
