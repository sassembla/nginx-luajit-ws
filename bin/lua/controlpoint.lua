
-- どっちにしても、nginx起動時にこのプロセスを開始しておきたい。
-- あとリセッタが欲しい。なんらか、redisに対してすべての破棄をお願いしたい。
-- あとredisでのpub-subやめたいな。あの性質、別の方法で実現できないかな。

IDENTIFIER_CENTRAL = "central"
IDENTIFIER_CLIENT = "client"

local json = require "json.json"
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



function control (from, data)

	-- do something here.

	ngx.log(ngx.ERR, "from:", from, " data:", data)

	-- publish(data, to)
	-- publish(data, to1, to2, ,,,)
	-- publish(data)

	publish(data)
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
			local id = dataDict.connectionId
			local data = dataDict.data

			control(id, data)
		end
	end
end

main()



