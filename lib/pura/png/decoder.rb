# frozen_string_literal: true

require "zlib"

module Pura
  module Png
    class Decoder
      PNG_SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10].pack("C8")

      # Color types
      GRAYSCALE       = 0
      RGB             = 2
      INDEXED         = 3
      GRAYSCALE_ALPHA = 4
      RGBA            = 6

      def self.decode(input)
        data = if input.is_a?(String) && !input.include?("\x00") && input.bytesize < 4096 && File.exist?(input)
                 File.binread(input)
               else
                 input.b
               end
        new(data).decode
      end

      def initialize(data)
        @data = data
        @pos = 0
      end

      def decode
        read_signature

        ihdr = nil
        palette = nil
        transparency = nil
        idat_chunks = []

        loop do
          length, type = read_chunk_header
          chunk_data = read_bytes(length)
          _crc = read_uint32

          case type
          when "IHDR"
            ihdr = parse_ihdr(chunk_data)
          when "PLTE"
            palette = parse_plte(chunk_data)
          when "tRNS"
            transparency = chunk_data
          when "IDAT"
            idat_chunks << chunk_data
          when "IEND"
            break
          end
        end

        raise "Missing IHDR chunk" unless ihdr
        raise "Missing IDAT chunk" if idat_chunks.empty?

        compressed = idat_chunks.join
        raw = Zlib::Inflate.inflate(compressed)

        pixels = reconstruct(raw, ihdr, palette, transparency)
        Image.new(ihdr[:width], ihdr[:height], pixels)
      end

      private

      def read_signature
        sig = read_bytes(8)
        raise "Not a PNG file" unless sig == PNG_SIGNATURE
      end

      def read_chunk_header
        length = read_uint32
        type = read_bytes(4)
        [length, type]
      end

      def read_bytes(n)
        raise "Unexpected end of data" if @pos + n > @data.bytesize

        result = @data.byteslice(@pos, n)
        @pos += n
        result
      end

      def read_uint32
        bytes = read_bytes(4)
        bytes.unpack1("N")
      end

      def parse_ihdr(data)
        width, height, bit_depth, color_type, compression, filter, interlace = data.unpack("NNC5")
        raise "Unsupported compression method: #{compression}" unless compression.zero?
        raise "Unsupported filter method: #{filter}" unless filter.zero?
        raise "Interlaced PNGs (Adam7) are not supported" unless interlace.zero?

        {
          width: width,
          height: height,
          bit_depth: bit_depth,
          color_type: color_type,
          interlace: interlace
        }
      end

      def parse_plte(data)
        raise "PLTE chunk length not divisible by 3" unless (data.bytesize % 3).zero?

        entries = data.bytesize / 3
        palette = Array.new(entries)
        entries.times do |i|
          offset = i * 3
          palette[i] = [data.getbyte(offset), data.getbyte(offset + 1), data.getbyte(offset + 2)]
        end
        palette
      end

      def bytes_per_pixel(ihdr)
        case ihdr[:color_type]
        when GRAYSCALE       then 1
        when RGB             then 3
        when INDEXED         then 1
        when GRAYSCALE_ALPHA then 2
        when RGBA            then 4
        else raise "Unknown color type: #{ihdr[:color_type]}"
        end
      end

      def samples_per_pixel(ihdr)
        case ihdr[:color_type]
        when GRAYSCALE       then 1
        when RGB             then 3
        when INDEXED         then 1
        when GRAYSCALE_ALPHA then 2
        when RGBA            then 4
        else raise "Unknown color type: #{ihdr[:color_type]}"
        end
      end

      def reconstruct(raw, ihdr, palette, transparency)
        width = ihdr[:width]
        height = ihdr[:height]
        bit_depth = ihdr[:bit_depth]
        color_type = ihdr[:color_type]
        bpp = bytes_per_pixel(ihdr)

        # For sub-byte pixels, compute scanline byte width
        if bit_depth < 8
          pixels_per_byte = 8 / bit_depth
          scanline_bytes = ((width * samples_per_pixel(ihdr)) + pixels_per_byte - 1) / pixels_per_byte
        else
          scanline_bytes = width * bpp * (bit_depth / 8)
        end

        # Bytes per complete pixel (for filter reconstruction, minimum 1)
        filter_bpp = [bpp * (bit_depth / 8), 1].max

        prev_row = "\0".b * scanline_bytes
        pos = 0
        out = String.new(encoding: Encoding::BINARY, capacity: width * height * 3)

        # Parse tRNS for grayscale/RGB transparency
        trns_gray = nil
        trns_rgb = nil
        trns_alpha = nil
        if transparency
          case color_type
          when GRAYSCALE
            trns_gray = transparency.unpack1("n")
          when RGB
            trns_rgb = transparency.unpack("nnn")
          when INDEXED
            trns_alpha = transparency.bytes
          end
        end

        height.times do
          filter_type = raw.getbyte(pos)
          pos += 1
          row_data = raw.byteslice(pos, scanline_bytes).bytes
          pos += scanline_bytes

          # Apply filter
          filtered = apply_filter(filter_type, row_data, prev_row.bytes, filter_bpp)
          prev_row = filtered.pack("C*")

          # Convert to RGB pixels
          convert_row_to_rgb(out, filtered, width, bit_depth, color_type, palette, trns_gray, trns_rgb, trns_alpha)
        end

        out
      end

      def apply_filter(filter_type, row, prev_row, bpp)
        case filter_type
        when 0 # None
          row
        when 1 # Sub
          row.each_with_index do |byte, i|
            left = i >= bpp ? row[i - bpp] : 0
            row[i] = (byte + left) & 0xFF
          end
          row
        when 2 # Up
          row.each_with_index do |byte, i|
            row[i] = (byte + prev_row[i]) & 0xFF
          end
          row
        when 3 # Average
          row.each_with_index do |byte, i|
            left = i >= bpp ? row[i - bpp] : 0
            up = prev_row[i]
            row[i] = (byte + ((left + up) / 2)) & 0xFF
          end
          row
        when 4 # Paeth
          row.each_with_index do |byte, i|
            left = i >= bpp ? row[i - bpp] : 0
            up = prev_row[i]
            up_left = i >= bpp ? prev_row[i - bpp] : 0
            row[i] = (byte + paeth_predictor(left, up, up_left)) & 0xFF
          end
          row
        else
          raise "Unknown filter type: #{filter_type}"
        end
      end

      def paeth_predictor(a, b, c)
        p = a + b - c
        pa = (p - a).abs
        pb = (p - b).abs
        pc = (p - c).abs
        if pa <= pb && pa <= pc
          a
        elsif pb <= pc
          b
        else
          c
        end
      end

      def convert_row_to_rgb(out, row, width, bit_depth, color_type, palette, _trns_gray, _trns_rgb, _trns_alpha)
        case color_type
        when RGB
          if bit_depth == 8
            width.times do |x|
              offset = x * 3
              out << row[offset].chr << row[offset + 1].chr << row[offset + 2].chr
            end
          elsif bit_depth == 16
            width.times do |x|
              offset = x * 6
              out << (row[offset] & 0xFF).chr << (row[offset + 2] & 0xFF).chr << (row[offset + 4] & 0xFF).chr
            end
          end

        when RGBA
          if bit_depth == 8
            width.times do |x|
              offset = x * 4
              out << row[offset].chr << row[offset + 1].chr << row[offset + 2].chr
            end
          elsif bit_depth == 16
            width.times do |x|
              offset = x * 8
              out << (row[offset] & 0xFF).chr << (row[offset + 2] & 0xFF).chr << (row[offset + 4] & 0xFF).chr
            end
          end

        when GRAYSCALE
          if bit_depth == 8
            width.times do |x|
              g = row[x]
              out << g.chr << g.chr << g.chr
            end
          elsif bit_depth == 16
            width.times do |x|
              g = row[x * 2]
              out << g.chr << g.chr << g.chr
            end
          elsif bit_depth < 8
            max_val = (1 << bit_depth) - 1
            pixels_per_byte = 8 / bit_depth
            mask = max_val
            x = 0
            byte_idx = 0
            while x < width
              byte = row[byte_idx]
              pixels_per_byte.times do |p|
                break if x >= width

                shift = 8 - (bit_depth * (p + 1))
                val = (byte >> shift) & mask
                g = (val * 255 / max_val)
                out << g.chr << g.chr << g.chr
                x += 1
              end
              byte_idx += 1
            end
          end

        when GRAYSCALE_ALPHA
          if bit_depth == 8
            width.times do |x|
              offset = x * 2
              g = row[offset]
              out << g.chr << g.chr << g.chr
            end
          elsif bit_depth == 16
            width.times do |x|
              offset = x * 4
              g = row[offset]
              out << g.chr << g.chr << g.chr
            end
          end

        when INDEXED
          raise "Missing PLTE for indexed color" unless palette

          if bit_depth == 8
            width.times do |x|
              idx = row[x]
              r, g, b = palette[idx]
              out << r.chr << g.chr << b.chr
            end
          elsif bit_depth < 8
            max_val = (1 << bit_depth) - 1
            pixels_per_byte = 8 / bit_depth
            mask = max_val
            x = 0
            byte_idx = 0
            while x < width
              byte = row[byte_idx]
              pixels_per_byte.times do |p|
                break if x >= width

                shift = 8 - (bit_depth * (p + 1))
                idx = (byte >> shift) & mask
                r, g, b = palette[idx]
                out << r.chr << g.chr << b.chr
                x += 1
              end
              byte_idx += 1
            end
          end
        end
      end
    end
  end
end
