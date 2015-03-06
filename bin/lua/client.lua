IDENTIFIER_CENTRAL = "central"
IDENTIFIER_CLIENT = "client"



-- entrypoint for WebSocket client connecttion.


-- setup redis pub-sub
local redis = require "redis.redis"


subRedisCon = redis:new()

local ok, err = subRedisCon:connect("127.0.0.1", 6379)

if not ok then
	ngx.log(ngx.ERR, "failed to generate subscriver")
	return
end


pubRedisCon = redis:new()

local ok, err = subRedisCon:subscribe(IDENTIFIER_CLIENT)
if not ok then
	ngx.log(ngx.ERR, "failed to start subscriver")
	return
end

local ok, err = pubRedisCon:connect("127.0.0.1", 6379)
if not ok then
	ngx.log(ngx.ERR, "failed to generate publisher")
	return
end


-- setup websocket client
local wsServer = require "websocket.server"

wb, wErr = wsServer:new{
	timeout = 10000000,
	max_payload_len = 65535
}

if not wb then
	ngx.log(ngx.ERR, "failed to new websocket: ", wErr)
	return ngx.exit(444)
end



function connectWebSocket()
	-- start subscribe
	ngx.thread.spawn(subscribe)

	-- start websocket serving
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
			pubRedisCon:publish(IDENTIFIER_CENTRAL, data)
		end
	end

	wb:send_close()
end

-- subscribe loop
-- waiting data from central.
function subscribe ()
	while true do
		local res, err = subRedisCon:read_reply()
		if not res then
			ngx.log(ngx.ERR, "redis subscribe read error:", err)
		else
			-- for i,v in ipairs(res) do
			-- 	ngx.log(ngx.ERR, "client i:", i, " v:", v)
			-- end

			-- send message with WebSocket for all subscribers.
			local bytes, err = wb:send_text(res[3])

			if not bytes then
				ngx.log(ngx.ERR, "failed to send text:", err)
				return ngx.exit(444)
			end

		end
	end
end

connectWebSocket()
