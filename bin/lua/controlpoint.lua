IDENTIFIER_CENTRAL = "central"
IDENTIFIER_CLIENT = "client"


function main ()
	-- start subscribe message to central
	local redis = require("redis.redis")
	
	-- generate subscriber for the message from clients
	local subRedisCon = redis:new()
	local ok, err = subRedisCon:connect("127.0.0.1", 6379)
	if not ok then
		ngx.log(ngx.ERR, "failed to generate central subscriber")
	end
	subRedisCon:set_timeout(1000 * 60 * 60)
	local ok, err = subRedisCon:subscribe(IDENTIFIER_CENTRAL)
	if not ok then
		ngx.log(ngx.ERR, "failed to start subscribe central subscriber")
	end


	-- generate publisher to clients
	local pubRedisCon = redis:new()
	local ok, err = pubRedisCon:connect("127.0.0.1", 6379)
	if not ok then
		ngx.log(ngx.ERR, "failed to generate central publisher")
	end


	-- start waiting loop
	while true do
		local res, err = subRedisCon:read_reply()
		if not res then
			ngx.log(ngx.ERR, "failed to receiving data from clients, err:", err)
		else
			-- for i,v in ipairs(res) do
			-- 	ngx.log(ngx.ERR, "central i:", i, " v:", v)
			-- end

			pubRedisCon:publish(IDENTIFIER_CLIENT, res[3])
		end
	end
end



main()



