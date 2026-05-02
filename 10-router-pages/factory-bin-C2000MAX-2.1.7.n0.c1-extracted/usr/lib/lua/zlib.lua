
require 'std'
local zlib = require '_zlib'
local tmpbuf = tmpbuf

function zlib.compress(input, output)
    if input == tmpbuf and not output then
        error('zlib.compress(): inbuf conflicts with tmpbuf when output is not provided')
    end

    local zstream, err = zlib.deflate_init()
    if zstream then
        err = zlib.deflate(zstream, input, output or tmpbuf:rewind(), 0)
        zlib.deflate_end(zstream)
        if err == 0 and not output then
            input:rewind():putreader(tmpbuf:reader())
        end
    end
    return err
end

function zlib.uncompress(input, output)
    if input == tmpbuf and not output then
        error('zlib.uncompress(): inbuf conflicts with tmpbuf when output is not provided')
    end

    local zstream, err = zlib.inflate_init()
    if zstream then
        err = zlib.inflate(zstream, input, output or tmpbuf:rewind(), 0)
        zlib.inflate_end(zstream)
        if err == 0 and not output then
            input:rewind():putreader(tmpbuf:reader())
        end
    end
    return err
end

return zlib
