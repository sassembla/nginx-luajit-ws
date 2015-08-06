-- game context for lua.

IDENTIFIER_CENTRAL = "central"
IDENTIFIER_CLIENT = "client"

ORDER_RESET = "reset"


STATE_CONNECT = "connect"
STATE_MESSAGE = "message"
STATE_DISCONNECT_1 = "disconnect1"
STATE_DISCONNECT_2 = "disconnect2"

DISCONNECT_REASON_ERROR = "client disconnected with error."
DISCONNECT_REASON_CLOSED = "client closed."

-- 100/sec context framerate.
TIMESPAN_WAIT = 0.01


local json = require "json.json"
local redis = require("redis.redis")

local keepalive = true

--[[]
	game context for all connecting players implemented by lua.
	you can use local parameters and table(dictionary)s like local application.
]]
local context = {}


local connections = {}
local count = 0

function context.onConnect(from, publish)
	ngx.log(ngx.ERR, "connect from:", from)
end

function context.onMessage(from, data, publish)
	-- do something here.
	ngx.log(ngx.ERR, "message from:", from, " data:", data)

	-- publish(data, to)
	-- publish(data, to1, to2, ,,,)
	-- publish(data)

	publish(data)
end

function context.onDisconnect(from, reason, publish)
	ngx.log(ngx.ERR, "disconnect from:", from, " reason:", reason)
end

function context.onUpdate(publish)
	if count % 100 == 0 then 
		ngx.log(ngx.ERR, "gameContext frame countUp:" .. count)
		publish("gameContext frame countUp:" .. count)
	end

	count = count + 1
end




--[[]
	below are basement of context.
]]

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


function publish (dataSource, ...)
	local targetIds = { ... }
	if 0 < #targetIds then
		local packData = json:encode({targets = targetIds, data = dataSource})
		pubRedisCon:publish(IDENTIFIER_CLIENT, packData)
		return
	end

	pubRedisCon:publish(IDENTIFIER_CLIENT, json:encode({data = dataSource}))
end

function update ()
	while true do
		context.onUpdate(publish)
		ngx.sleep(TIMESPAN_WAIT)
	end
end

function messageReceiving ()
	-- start waiting loop. prevent return response to original request.
	while true do
		local res, err = subRedisCon:read_reply()
		if not res then
			ngx.log(ngx.ERR, "failed to receiving data from message queue, err:", err)
			ngx.exit(200)
			return
		else
			-- for i,v in ipairs(res) do
			-- 	ngx.log(ngx.ERR, "central i:", i, " v:", v)
			-- end

			local dataDict = json:decode(res[3])
			
			local state = dataDict.state
			local id = dataDict.connectionId
			local data = dataDict.data

			control(state, id, data)
		end
	end
end

ngx.thread.spawn(update)
ngx.thread.spawn(messageReceiving)



ngx.log(ngx.ERR, "game context added!")



-- setup websocket client
local wsServer = require "ws.websocketServer"

wb, wErr = wsServer:new{
	timeout = 10000000,
	max_payload_len = 65535
}

if not wb then
	ngx.log(ngx.ERR, "failed to new websocket: ", wErr)
	return ngx.exit(444)
end

-- start websocket serving
while true do
	local recv_data, typ, err = wb:recv_frame()

	if wb.fatal then
		return ngx.exit(444)
	end
	if not recv_data then
		local bytes, err = wb:send_ping()
		if not bytes then
			ngx.log(ngx.ERR, "failed to send ping: ", err)
			return ngx.exit(444)
		end
	end

	if typ == "close" then
		ngx.log(ngx.ERR, "connection closed:", serverId)
		break
	elseif typ == "ping" then
		local bytes, err = wb:send_pong()
		if not bytes then
			ngx.log(ngx.ERR, "failed to send pong: ", err)
			return ngx.exit(444)
		end
	elseif typ == "pong" then
		ngx.log(ngx.ERR, "client ponged")

	elseif typ == "text" then
		ngx.log(ngx.ERR, "break this game context.")
		ngx.exit(200)
		break;
	end
end

wb:send_close()
