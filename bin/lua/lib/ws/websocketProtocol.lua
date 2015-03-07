local bit = require "bit"
local uuid = require "uuid.uuid"

local M = {[0] = "websocketProtocol:" .. uuid.getUUID()}

local types = {
    [0x0] = "continuation",
    [0x1] = "text",
    [0x2] = "binary",
    [0x8] = "close",
    [0x9] = "ping",
    [0xa] = "pong",
}

function M.recv_frame(sock, max_payload_len, force_masking)
    local data, err = sock:receive(2)
    if not data then
        return nil, nil, "failed to receive the first 2 bytes: " .. err
    end

    local fst, snd = string.byte(data, 1, 2)

    local fin = bit.band(fst, 0x80) ~= 0

    if bit.band(fst, 0x70) ~= 0 then
        return nil, nil, "bad RSV1, RSV2, or RSV3 bits"
    end

    local opcode = bit.band(fst, 0x0f)

    if opcode >= 0x3 and opcode <= 0x7 then
        return nil, nil, "reserved non-control frames"
    end

    if opcode >= 0xb and opcode <= 0xf then
        return nil, nil, "reserved control frames"
    end

    local mask = bit.band(snd, 0x80) ~= 0

    if force_masking and not mask then
        return nil, nil, "frame unmasked"
    end

    local payload_len = bit.band(snd, 0x7f)

    if payload_len == 126 then
        local data, err = sock:receive(2)
        if not data then
            return nil, nil, "failed to receive the 2 byte payload length: "
                             .. (err or "unknown")
        end

        payload_len = bit.bor(bit.lshift(string.byte(data, 1), 8), string.byte(data, 2))

    elseif payload_len == 127 then
        local data, err = sock:receive(8)
        if not data then
            return nil, nil, "failed to receive the 8 byte payload length: "
                             .. (err or "unknown")
        end

        if string.byte(data, 1) ~= 0
           or string.byte(data, 2) ~= 0
           or string.byte(data, 3) ~= 0
           or string.byte(data, 4) ~= 0
        then
            return nil, nil, "payload len too large"
        end

        local fifth = string.byte(data, 5)
        if bit.band(fifth, 0x80) ~= 0 then
            return nil, nil, "payload len too large"
        end

        payload_len = bit.bor(bit.lshift(fifth, 24),
                          bit.lshift(string.byte(data, 6), 16),
                          bit.lshift(string.byte(data, 7), 8),
                          string.byte(data, 8))
    end

    if bit.band(opcode, 0x8) ~= 0 then
        -- being a control frame
        if payload_len > 125 then
            return nil, nil, "too long payload for control frame"
        end

        if not fin then
            return nil, nil, "fragmented control frame"
        end
    end

    -- print("payload len: ", payload_len, ", max payload len: ",
          -- max_payload_len)

    if payload_len > max_payload_len then
        return nil, nil, "exceeding max payload len"
    end

    local rest
    if mask then
        rest = payload_len + 4

    else
        rest = payload_len
    end
    -- print("rest: ", rest)

    local data
    if rest > 0 then
        data, err = sock:receive(rest)
        if not data then
            return nil, nil, "failed to read masking-len and payload: "
                             .. (err or "unknown")
        end
    else
        data = ""
    end

    -- print("received rest")

    if opcode == 0x8 then
        -- being a close frame
        if payload_len > 0 then
            if payload_len < 2 then
                return nil, nil, "close frame with a body must carry a 2-byte"
                                 .. " status code"
            end

            local msg, code
            if mask then
                local fst = bit.bxor(byte(data, 4 + 1), string.byte(data, 1))
                local snd = bit.bxor(byte(data, 4 + 2), string.byte(data, 2))
                code = bit.bor(bit.lshift(fst, 8), snd)

                if payload_len > 2 then
                    -- TODO string.buffer optimizations
                    local bytes = table.new(payload_len - 2, 0)
                    for i = 3, payload_len do
                        bytes[i - 2] = string.char(bit.bxor(string.byte(data, 4 + i),
                                                     string.byte(data,
                                                          (i - 1) % 4 + 1)))
                    end
                    msg = table.concat(bytes)

                else
                    msg = ""
                end

            else
                local fst = string.byte(data, 1)
                local snd = string.byte(data, 2)
                code = bit.bor(bit.lshift(fst, 8), snd)

                -- print("parsing unmasked close frame payload: ", payload_len)

                if payload_len > 2 then
                    msg = string.sub(data, 3)

                else
                    msg = ""
                end
            end

            return msg, "close", code
        end

        return "", "close", nil
    end

    local msg
    if mask then
        -- TODO string.buffer optimizations
        local bytes = table.new(payload_len, 0)
        for i = 1, payload_len do
            bytes[i] = string.char(bit.bxor(string.byte(data, 4 + i), string.byte(data, (i - 1) % 4 + 1)))
        end
        msg = table.concat(bytes)

    else
        msg = data
    end

    return msg, types[opcode], not fin and "again" or nil
end


local function build_frame(fin, opcode, payload_len, payload, masking)
    -- XXX optimize this when we have string.buffer in LuaJIT 2.1
    local fst
    if fin then
        fst = bit.bor(0x80, opcode)
    else
        fst = opcode
    end

    local snd, extra_len_bytes
    if payload_len <= 125 then
        snd = payload_len
        extra_len_bytes = ""

    elseif payload_len <= 65535 then
        snd = 126
        extra_len_bytes = string.char(bit.band(bit.rshift(payload_len, 8), 0xff),
                               bit.band(payload_len, 0xff))

    else
        if bit.band(payload_len, 0x7fffffff) < payload_len then
            return nil, "payload too big"
        end

        snd = 127
        -- XXX we only support 31-bit length here
        extra_len_bytes = string.char(0, 0, 0, 0, bit.band(bit.rshift(payload_len, 24), 0xff),
                               bit.band(bit.rshift(payload_len, 16), 0xff),
                               bit.band(bit.rshift(payload_len, 8), 0xff),
                               bit.band(payload_len, 0xff))
    end

    local masking_key
    if masking then
        -- set the mask bit
        snd = bit.bor(snd, 0x80)
        local key = math.random(0xffffffff)
        masking_key = string.char(bit.band(bit.rshift(key, 24), 0xff),
                           bit.band(bit.rshift(key, 16), 0xff),
                           bit.band(bit.rshift(key, 8), 0xff),
                           bit.band(key, 0xff))

        -- TODO string.buffer optimizations
        local bytes = table.new(payload_len, 0)
        for i = 1, payload_len do
            bytes[i] = string.char(bit.bxor(string.byte(payload, i),
                                     string.byte(masking_key, (i - 1) % 4 + 1)))
        end
        payload = table.concat(bytes)

    else
        masking_key = ""
    end

    return string.char(fst, snd) .. extra_len_bytes .. masking_key .. payload
end
M.build_frame = build_frame


function M.send_frame(sock, fin, opcode, payload, max_payload_len, masking)
    if not payload then
        payload = ""

    elseif type(payload) ~= "string" then
        payload = tostring(payload)
    end

    local payload_len = #payload

    if payload_len > max_payload_len then
        return nil, "payload too big"
    end

    if bit.band(opcode, 0x8) ~= 0 then
        -- being a control frame
        if payload_len > 125 then
            return nil, "too much payload for control frame"
        end
        if not fin then
            return nil, "fragmented control frame"
        end
    end

    local frame, err = build_frame(fin, opcode, payload_len, payload,
                                   masking)
    if not frame then
        return nil, "failed to build frame: " .. err
    end

    local bytes, err = sock:send(frame)
    if not bytes then
        return nil, "failed to send frame: " .. err
    end
    return bytes
end


return M
