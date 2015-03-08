--[[]
	ゲームとか書けるところ。あとコンテキストの名の通り、データベースに依存せずにパラメータとか持てるぞ。
]]
local M = {}


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

-- 100f/secくらい、ただし、すべてのルームが同期で動く。
function M.onFrame(publish)

end



return M