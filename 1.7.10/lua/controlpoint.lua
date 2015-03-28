
-- どっちにしても、nginx起動時にこのプロセスを開始しておきたい。
-- あとredisでのpub-subやめたいな。あの性質、別の方法で実現できないかな。

IDENTIFIER_CENTRAL = "central"
IDENTIFIER_CLIENT = "client"

ORDER_RESET = "reset"

TIMESPAN_WAIT = 0.01

STATE_CONNECT = "connect"
STATE_MESSAGE = "message"
STATE_DISCONNECT_1 = "disconnect1"
STATE_DISCONNECT_2 = "disconnect2"

DISCONNECT_REASON_ERROR = "client disconnected with error."
DISCONNECT_REASON_CLOSED = "client closed."


local json = require "json.json"
local redis = require("redis.redis")



local context = require("context")



-- generate subscriber for the message from clients
local subRedisCon = redis:new()
local ok, err = subRedisCon:connect("127.0.0.1", 6379)
if not ok then
	ngx.log(ngx.ERR, "failed to generate central subscriber:", err)
	ngx.exit(500)
	return
end
subRedisCon:set_timeout(1000 * 60 * 60)
local ok, err = subRedisCon:subscribe(IDENTIFIER_CENTRAL)
if not ok then
	ngx.log(ngx.ERR, "failed to start subscribe central subscriber:", err)
	ngx.exit(500)
	return
end

-- generate publisher to clients
local pubRedisCon = redis:new()
local ok, err = pubRedisCon:connect("127.0.0.1", 6379)
if not ok then
	ngx.log(ngx.ERR, "failed to generate central publisher:", err)
	ngx.exit(500)
	return
end


function control (state, from, ...)
	if state == STATE_MESSAGE then
		data = {...}
		context.onMessage(from, data[1], publish)
	end

	if state == STATE_CONNECT then
		context.onConnect(from, publish)
		return
	end

	if state == STATE_DISCONNECT_1 then
		context.onDisconnect(from, DISCONNECT_REASON_ERROR, publish)
		return
	end

	if state == STATE_DISCONNECT_2 then
		context.onDisconnect(from, DISCONNECT_REASON_CLOSED, publish)
		return
	end
end


function tick ()
	while true do
		context.onFrame(publish)
		ngx.sleep(TIMESPAN_WAIT)
	end
end


function publish (dataSource, ...)
	local targetIds = { ... }
	if 0 < #targetIds then
		local packData = json:encode({targets = targetIds, data = dataSource})
		pubRedisCon:publish(IDENTIFIER_CLIENT, packData)
		return
	end

	pubRedisCon:publish(IDENTIFIER_CLIENT, json:encode({data = dataSource}))
end


function main ()
	-- start waiting loop
	while true do
		local res, err = subRedisCon:read_reply()
		if not res then
			ngx.log(ngx.ERR, "failed to receiving data from clients, err:", err)
			ngx.exit(500)
			return
		else
			-- for i,v in ipairs(res) do
			-- 	ngx.log(ngx.ERR, "central i:", i, " v:", v)
			-- end

			local dataDict = json:decode(res[3])
			
			local order = dataDict.order

			local state = dataDict.state
			local id = dataDict.connectionId
			local data = dataDict.data

			if not order then
				control(state, id, data)
			else
				if doOrder(order) < 0 then
					ngx.log(ngx.ERR, "order:", order)
					subRedisCon:unsubscribe(IDENTIFIER_CENTRAL)
					return ngx.exit(200)
					-- setsockopt(TCP_NODELAY) failed (22: Invalid argument) while keepalive, client: 127.0.0.1, server: 0.0.0.0:80 が出ている気がする
				end
			end
		end
	end
end

function doOrder (order)
	if order == ORDER_RESET then
		return -1
	end

	return 1
end


-- start tick.
ngx.thread.spawn(tick)


-- start waiting publish from client.
main()



