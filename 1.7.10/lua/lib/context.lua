--[[]
	context for all connecting players.
	you can use local parameters and table(dictionary)s like local application.
]]
local M = {}

connections = {}

count = 0

function M.onConnect(from, publish)
	ngx.log(ngx.ERR, "connect from:", from)
end

function M.onMessage(from, data, publish)
	-- do something here.
	ngx.log(ngx.ERR, "message from:", from, " data:", data)

	-- publish(data, to)
	-- publish(data, to1, to2, ,,,)
	-- publish(data)

	publish(data)
end

function M.onDisconnect(from, reason, publish)
	ngx.log(ngx.ERR, "disconnect from:", from, " reason:", reason)
end

function M.onFrame(publish)
	if count % 100 == 0 then publish("data!:" .. count) end
	count = count + 1
end

return M