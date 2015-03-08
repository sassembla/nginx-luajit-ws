
-- どっちにしても、nginx起動時にこのプロセスを開始しておきたい。
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

	-- do some code here

	ngx.log(ngx.ERR, "from:", from, " data:", data)

	-- 無視、単体に返す、複数に返す、全体に返す、のどれか
	-- dataとtargets、targets無しで全体、みたいな関数
	-- ここで最適化してもなあって感じはある。そもデータに入れないでOKなら、っていう選択肢もあるんで。
	-- データを人数分入れる形式のほうがラクなようなきがするが、シングルトンとかを考えると面倒くさいのか。
	-- そも全体、受けがわで切る、とかが一番ラクなんだが、その戦略をとるなら無視できる。無駄な通信なのでやりたくはない。
	-- publishTo(data, from)
	-- publishTo(data, from, other)
	-- publish(data)
end


-- function publish (dataSource)
-- 	local data = json.encode({[""]})
-- 	pubRedisCon:publish(IDENTIFIER_CLIENT, data)
-- end


function main ()
	-- start waiting loop
	while true do
		local res, err = subRedisCon:read_reply()
		if not res then
			ngx.log(ngx.ERR, "failed to receiving data from clients, err:", err)
			ngx.exit(500)
			return
		else
			for i,v in ipairs(res) do
				ngx.log(ngx.ERR, "central i:", i, " v:", v)
			end

			local dataDict = json:decode(res[3])
			local id = dataDict.connectionId
			local data = dataDict.data

			control(id, data)
		end
	end
end

main()



