local bit = require "bit"
local protocol = require "ws.websocketProtocol"
local uuid = require "uuid.uuid"

local M = {[0] = "websocketServer:" .. uuid.getUUID()}
local mt = { __index = M }

function M.new(self, opts)
    if ngx.headers_sent then
        return nil, "response header already sent"
    end

    -- construct WebSocket connect from server to client.

    -- discard body
    ngx.req.read_body()

    -- check header
    if ngx.req.http_version() ~= 1.1 then
        return nil, "bad http version"
    end

    local headers = ngx.req.get_headers()

    local val = headers.upgrade
    if type(val) == "table" then
        val = val[1]
    end
    if not val or string.lower(val) ~= "websocket" then
        return nil, "bad \"upgrade\" request header"
    end

    val = headers.connection
    if type(val) == "table" then
        val = val[1]
    end
    if not val or not string.find(string.lower(val), "upgrade", 1, true) then
        return nil, "bad \"connection\" request header"
    end

    local key = headers["sec-websocket-key"]
    if type(key) == "table" then
        key = key[1]
    end
    if not key then
        return nil, "bad \"sec-websocket-key\" request header"
    end

    local ver = headers["sec-websocket-version"]
    if type(ver) == "table" then
        ver = ver[1]
    end
    if not ver or ver ~= "13" then
        return nil, "bad \"sec-websocket-version\" request header"
    end

    local protocols = headers["sec-websocket-protocol"]
    if type(protocols) == "table" then
        protocols = protocols[1]
    end

    if protocols then
        ngx.header["Sec-WebSocket-Protocol"] = protocols
    end
    ngx.header["Upgrade"] = "websocket"

    local sha1 = ngx.sha1_bin(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
    ngx.header["Sec-WebSocket-Accept"] = ngx.encode_base64(sha1)

    ngx.header["Content-Type"] = nil

    ngx.status = 101
    local ok, err = ngx.send_headers()
    if not ok then
        return nil, "failed to send response header: " .. (err or "unknonw")
    end
    ok, err = ngx.flush(true)
    if not ok then
        return nil, "failed to flush response header: " .. (err or "unknown")
    end

    local sock
    sock, err = ngx.req.socket(true)
    if not sock then
        return nil, err
    end

    local max_payload_len, send_masked, timeout
    if opts then
        max_payload_len = opts.max_payload_len
        send_masked = opts.send_masked
        timeout = opts.timeout

        if timeout then
            sock:settimeout(timeout)
        end
    end

    return setmetatable({
        sock = sock,
        max_payload_len = max_payload_len or 65535,
        send_masked = send_masked,
    }, mt)
end


function M.set_timeout(self, time)
    local sock = self.sock
    if not sock then
        return nil, nil, "not initialized yet"
    end

    return sock:settimeout(time)
end


function M.recv_frame(self)
    if self.fatal then
        return nil, nil, "fatal error already happened"
    end

    local sock = self.sock
    if not sock then
        return nil, nil, "not initialized yet"
    end

    local data, typ, err =  protocol.recv_frame(sock, self.max_payload_len, true)
    if not data and not string.find(err, ": timeout", 1, true) then
        self.fatal = true
    end
    return data, typ, err
end


local function send_frame(self, fin, opcode, payload)
    if self.fatal then
        return nil, "fatal error already happened"
    end

    local sock = self.sock
    if not sock then
        return nil, "not initialized yet"
    end

    local bytes, err = protocol.send_frame(sock, fin, opcode, payload,
                                   self.max_payload_len, self.send_masked)
    if not bytes then
        self.fatal = true
    end
    return bytes, err
end


M.send_frame = send_frame


function M.send_text(self, data)
    return send_frame(self, true, 0x1, data)
end


function M.send_binary(self, data)
    return send_frame(self, true, 0x2, data)
end


function M.send_close(self, code, msg)
    local payload
    if code then
        if type(code) ~= "number" or code > 0x7fff then
        end
        payload = string.char(bit.band(bit.rshift(code, 8), 0xff), bit.band(code, 0xff))
                        .. (msg or "")
    end
    return send_frame(self, true, 0x8, payload)
end


function M.send_ping(self, data)
    return send_frame(self, true, 0x9, data)
end


function M.send_pong(self, data)
    return send_frame(self, true, 0xa, data)
end


return M
