require 'iobuffer'

module Mp3file
    class InvalidMP3StreamError < Mp3fileError; end

    class MP3Stream
        attr_reader(:layer, :bitrate, :samplerate, :mode, :frame_headers, :xing_header)
        attr_reader(:first_header_offset, :mpeg_version, :first_header, :buffer)

        def initialize(initial_data)
            @buffer = IO::Buffer.new
            @buffer << initial_data
        end

        def start_stream_parse
            @skipped_bytes = 0
            @first_header_offset, @first_header = get_next_header
            @mpeg_version = @first_header.version
            @layer = @first_header.layer
            @bitrate = @first_header.bitrate / 1000
            @samplerate = @first_header.samplerate
            @mode = @first_header.mode
            @frame_headers = []
            @frame_headers << @first_header
            
            # Is there a Xing header? Hopefully not, since this is streamed...
            @xing_header = nil
            find_more_headers
        end
    
        def find_more_headers
            @last_header_offset = @first_header_offset
            loop do
                @buffer.seek(@last_header_offset + @frame_headers.last.frame_size)
                @last_header_offset, header = get_next_header
                if header.nil?
                    break
                else
                    @frame_headers << header
                end
            end
        end

        def vbr?
            unique_bitrates = @frame_headers.map { |h| h.bitrate }.uniq
            unique_bitrates.size > 1
        end

        def bitrate
            unless vbr?
                # If it's CBR, the bitrate is the same throughout. Take a shortcut
                # to get the math done faster.
                @first_header.bitrate / 1000
            else
                # If it's VBR, do an average bitrate calculation.
                @frame_headers.inject(0) { |sum, h| sum + h.bitrate } / num_frames
            end
        end

        def num_frames
            @frame_headers.size
        end
        
        def total_samples
            # Calculate the total number of samples. MPEG uses a constant number of
            # samples per frame
            num_frames * @first_header.samples
        end

        def length
            # Find the average sample rate so far
            avg_samplerate = (@frame_headers.inject(0) { |tot, f| tot + f.samplerate } / @frame_headers.size)
            # Calculate the length of the stream so far
            @total_samples.to_f / avg_samplerate.to_f
        end



        private

        def get_next_header(offset = nil)
            if offset && offset != buffer.tell
                @buffer.seek(offset, IO::SEEK_SET)
            end

           header = nil
           initial_header_offset = @buffer.tell
           header_offset = @buffer.tell
     
           while header.nil?
             begin
              header = MP3Header.new(@buffer)
              header_offset = @buffer.tell - 4
            rescue InvalidMP3HeaderError
              header_offset += 1
              if header_offset - initial_header_offset > 4096
                raise InvalidMP3StreamError, "Could not find a valid MP3 header in the first 4096 bytes."
              else
                @buffer.seek(header_offset, IO::SEEK_SET)
                retry
              end
            rescue EOFError
              break
            end
    
            # byte = file.readbyte
            # while byte != 0xFF
            #   byte = file.readbyte
            # end
            # header_bytes = [ byte ] + file.read(3).bytes.to_a
            # if header_bytes[1] & 0xE0 != 0xE0
            #   file.seek(-3, IO::SEEK_CUR)
            # else
            #   header = MP3Header.new(header_bytes)
            #   if !header.valid?
            #     header = nil
            #     file.seek(-3, IO::SEEK_CUR)
            #   else
            #     header_offset = file.tell - 4
            #   end
            # end
          end
    
          @skipped_bytes += header_offset - initial_header_offset
          if @skipped_bytes > 2048
            raise InvalidMP3StreamError, "Had to skip > 2048 bytes in between headers."
          end
    
          # if initial_header_offset != header_offset
          #   puts "Had to skip past #{header_offset - initial_header_offset} to find the next header. header_offset = #{header_offset} header = #{header.inspect}"
          # end
    
          [ header_offset, header ]
        end
    end
end
