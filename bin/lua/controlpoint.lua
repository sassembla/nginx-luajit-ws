IDENTIFIER_CENTRAL = "central"
IDENTIFIER_CLIENT = "client"

-- この部分がロジックになってしまっているので、切り離す。
-- 接続しているやつすべてに返す部分までは直通なんだけど、
-- 誰からか、+ 情報、という形式に変更する。情報の中身で誰宛か、を付ければ良い。
-- 誰からか、っていう情報は、connectionIdでもって判別する。
-- そのデータはpubを介してすべてのメッセージにくっつく前提。
-- connection っていうキーを作るか。
-- どっちにしても、nginx起動時にこのプロセスを開始しておきたい。
function main ()
	-- start subscribe message to central
	local redis = require("redis.redis")
	
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

			pubRedisCon:publish(IDENTIFIER_CLIENT, res[3])
		end
	end
end



main()



