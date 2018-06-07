-- Copyright (C) Yichun Zhang (agentzh)
-- Modified by whuben for supportting the Reverse-Proxy mode

-- local sub = string.sub
local req_socket = ngx.req.socket
local match = string.match
local setmetatable = setmetatable
local type = type
local ngx_var = ngx.var
local ngx_req = ngx.req
-- local print = print


local _M = { _VERSION = '0.10' }


local CHUNK_SIZE = 4096
local MAX_LINE_SIZE = 512

local STATE_BEGIN = 1
local STATE_READING_HEADER = 2
local STATE_READING_BODY = 3
local STATE_EOF = 4


local mt = { __index = _M }

local state_handlers


local function get_boundary()
    local header = ngx_var.content_type
    if not header then
        return nil
    end

    if type(header) == "table" then
        header = header[1]
    end

    local m = match(header, ";%s*boundary=\"([^\"]+)\"")
    if m then
        return m
    end

    return match(header, ";%s*boundary=([^\",;]+)")
end


function _M.new(self, chunk_size, max_line_size)
    local boundary = get_boundary()

    -- print("boundary: ", boundary)

    if not boundary then
        return nil, "no boundary defined in Content-Type"
    end

    -- print('boundary: "', boundary, '"')

    local sock, err = req_socket()
    if not sock then
        return nil, err
    end
    ngx_req.init_body() --create a new blank request body  and init the buffer for upload data 
    local read2boundary, err = sock:receiveuntil("--" .. boundary)
    if not read2boundary then
        ngx_req.finish_body() --complete the buffer appendding
        return nil, err
    end
    local read_line, err = sock:receiveuntil("\r\n")
    if not read_line then
        ngx_req.finish_body() --complete the buffer appendding
        return nil, err
    end

    return setmetatable({
        sock = sock,
        size = chunk_size or CHUNK_SIZE,
        line_size = max_line_size or MAX_LINE_SIZE,
        read2boundary = read2boundary,
        read_line = read_line,
        boundary = boundary,
        state = STATE_BEGIN
    }, mt)
end


function _M.set_timeout(self, timeout)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:settimeout(timeout)
end


local function discard_line(self)
    local read_line = self.read_line

    local line, err = read_line(self.line_size)
    if not line then
        return nil, err
    end
    ngx_req.append_body(line).  --append the line data into the buffer
    ngx_req.append_body("\r\n") --append the line pattern into the buffer
    local dummy, err = read_line(1)
    if dummy then
        return nil, "line too long: " .. line .. dummy .. "..."
    end

    if err then
        return nil, err
    end

    return 1
end


local function discard_rest(self)
    local sock = self.sock
    local size = self.size

    while true do
        local dummy, err = sock:receive(size)
        if err and err ~= 'closed' then
            return nil, err
        end

        if not dummy then
            return 1
        end
        ngx_req.append_body(dummy) --just append the dummy data into the buffer
    end
end


local function read_body_part(self)
    local read2boundary = self.read2boundary

    local chunk, err = read2boundary(self.size)
    if err then
        ngx_req.finish_body() --complete the buffer appendding
        return nil, nil, err
    end

    if not chunk then
        local sock = self.sock

        local data = sock:receive(2)
        if data == "--" then
            ngx_req.append_body("\r\n--"..self.boundary.."--") --(end of the body)append the last pattern string into the buffer
            local ok, err = discard_rest(self)
            if not ok then
                ngx_req.finish_body() --complete the buffer appendding
                return nil, nil, err
            end

            self.state = STATE_EOF
            return "part_end"
        end

        if data ~= "\r\n" then
            ngx_req.append_body("\r\n--"..self.boundary..data) --just append the pattern string into the buffer and then append the discard_line data
            local ok, err = discard_line(self)
            if not ok then
                ngx_req.finish_body() --complete the buffer appendding
                return nil, nil, err
            end
        else
            ngx_req.append_body("\r\n--"..self.boundary.."\r\n") --append the end pattern string of one file into the buffer
        end
        self.state = STATE_READING_HEADER
        return "part_end"
    end
    ngx_req.append_body(chunk) --append the body data into the buffer
    return "body", chunk
end


local function read_header(self)
    local read_line = self.read_line

    local line, err = read_line(self.line_size)
    if err then
        ngx_req.finish_body() --complete the buffer appendding
        return nil, nil, err
    end
    ngx_req.append_body(line).  --append the line data into the buffer
    ngx_req.append_body("\r\n") --append the line pattern into the buffer
    local dummy, err = read_line(1)
    if dummy then
        ngx_req.finish_body() --complete the buffer appendding
        return nil, nil, "line too long: " .. line .. dummy .. "..."
    end

    if err then
        ngx_req.finish_body() --complete the buffer appendding
        return nil, nil, err
    end

    -- print("read line: ", line)

    if line == "" then
        -- after the last header
        self.state = STATE_READING_BODY
        return read_body_part(self)
    end

    local key, value = match(line, "([^: \t]+)%s*:%s*(.+)")
    if not key then
        return 'header', line
    end

    return 'header', {key, value, line}
end


local function eof()
    ngx_req.finish_body() --complete the buffer appendding
    return "eof", nil
end


function _M.read(self)
    -- local size = self.size

    local handler = state_handlers[self.state]
    if handler then
        return handler(self)
    end

    return nil, nil, "bad state: " .. self.state
end


local function read_preamble(self)
    local sock = self.sock
    if not sock then
        return nil, nil, "not initialized"
    end

    local size = self.size
    local read2boundary = self.read2boundary

    while true do
        local preamble = read2boundary(size)
        if not preamble then
            ngx_req.append_body("--"..self.boundary) --append the pattern string into the buffer
            break
        end
        ngx_req.append_body(preamble) --append the data into buffer
        -- discard the preamble data chunk
        -- print("read preamble: ", preamble)
    end

    local ok, err = discard_line(self)
    if not ok then
        ngx_req.finish_body() --complete the buffer appendding
        return nil, nil, err
    end

    local read2boundary, err = sock:receiveuntil("\r\n--" .. self.boundary)
    if not read2boundary then
        ngx_req.finish_body() --complete the buffer appendding
        return nil, nil, err
    end

    self.read2boundary = read2boundary

    self.state = STATE_READING_HEADER
    return read_header(self)
end


state_handlers = {
    read_preamble,
    read_header,
    read_body_part,
    eof
}


return _M
