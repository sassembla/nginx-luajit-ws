-- まだコンテキストの設計は行わない。 WebSocketへの介入ができるのか？というところに興味がある。

local sock = ngx.socket.udp()
-- local graphite_host = ngx.var.graphite_host
-- local graphite_port = ngx.var.graphite_port
-- local ok, err = sock:setpeername(graphite_host, tonumber(graphite_port))
-- if not ok then
--     ngx.say(err)
--     return
-- end

-- ngx.req.read_body()
-- local args, err = ngx.req.get_post_args()
-- if not args then
--     ngx.say(err)
--     return
-- end

-- local path = args.path
-- local value = args.value

-- local timestamp = os.time()
-- local data = table.concat({path, value, tostring(timestamp)}, " ")
-- local ok, err = sock:send(data)
-- if err then
--     ngx.say(err)
--     return
-- end

-- local ok, err = sock:close()
-- if not ok then
--     ngx.say(err)
--     return
-- end

function dofile (filename)
    local f = assert(loadfile(filename))
    return f()
end

-- ngx.shared.stats:incr("hits", 1) なんじゃろ。
-- ngx.say(ngx.shared.stats:get("hits"))



function connectWebSocket()

	local server = require "websocket.server"
	local wb, err = server:new{
		timeout = 5000,
		max_payload_len = 65535
	}

	if not wb then
		ngx.log(ngx.ERR, "failed to new websocket: ", err)
		return ngx.exit(444)
	end

	while true do
		local data, typ, err = wb:recv_frame()
		if wb.fatal then
			ngx.log(ngx.ERR, "failed to receive frame: ", err)
			return ngx.exit(444)
		end
		if not data then
			local bytes, err = wb:send_ping()
			if not bytes then
				ngx.log(ngx.ERR, "failed to send ping: ", err)
				return ngx.exit(444)
			end
		elseif typ == "close" then break
		elseif typ == "ping" then
			local bytes, err = wb:send_pong()
			if not bytes then
				ngx.log(ngx.ERR, "failed to send pong: ", err)
				return ngx.exit(444)
			end
		elseif typ == "pong" then
			ngx.log(ngx.INFO, "client ponged")
		elseif typ == "text" then
			local bytes, err = wb:send_text(data)
			if not bytes then
				ngx.log(ngx.ERR, "failed to send text: ", err)
				return ngx.exit(444)
			end
		end
	end

	wb:send_close()
end



connectWebSocket()


-- これより後ろは切断時のやつなので読まれない。
-- そろそろ整理しよう。
-- function pwd(  )
--     ngx.say("here comes1!")
--     ngx.say("here comes2!")
-- end

-- -- dofile("")
-- pwd()
