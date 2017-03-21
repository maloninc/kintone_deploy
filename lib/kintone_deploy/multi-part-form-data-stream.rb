class MultiPartFormDataStream
    def initialize(filename, file, boundary=nil, content_type='text/plain')
        @boundary = boundary || "boundary"
        first = [boundary_line, content_disposition(filename), "content-type: #{content_type}", "", ""].join(new_line)
        last = ["", boundary_last, ""].join(new_line)
        @first = StringIO.new(first)
        @file = file
        @last = StringIO.new(last)
        @size = @first.size + @file.size + @last.size
    end
    def content_type
        "multipart/form-data; boundary=#{@boundary}"
    end
    def boundary_line
        "--#{@boundary}"
    end
    def boundary_last
        "--#{@boundary}--"
    end
    def content_disposition(filename)
        "content-disposition: form-data; name=\"file\"; filename=\"#{filename}\""
    end
    def new_line
        "\r\n"
    end
    def read(len=nil, buf=nil)
        return @first.read(len, buf) unless @first.eof?
        return @file.read(len, buf) unless @file.eof?
        return @last.read(len, buf)
    end
    def size
        @size
    end
    def eof?
        @last.eof?
    end
end
