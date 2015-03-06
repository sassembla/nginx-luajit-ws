function main ()
	local redis = require "redis.redis"
	local red = redis:new()
	local ok, err = red:connect("127.0.0.1", 6379)
	ngx.log(ngx.ERR, "1, main control restarted:", ok, " err:", err)
	
	local ok2, err2 = red:subscribe("str")
	ngx.log(ngx.ERR, "2!")

	pub()

	ngx.log(ngx.ERR, "3!")

	while true do

		local res, err = red:read_reply()
		if not res then
			ngx.log(ngx.ERR, "5!", err)
		end

		-- ngx.log(ngx.ERR, "4!", res)
		for i,v in ipairs(res) do
			ngx.log(ngx.ERR, "i:", i, " v:", v)
		end
		break
	end
end

function pub ()
	local redis = require "redis.redis"
	
	local red = redis:new()
	local ok, err = red:connect("127.0.0.1", 6379)
	
	res, err = red:publish("str", "Hello")
	if not res then
		ngx.log(ngx.ERR, "err:", err)
	end
end

main()