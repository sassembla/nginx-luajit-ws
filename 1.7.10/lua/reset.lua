-- reset central point.

IDENTIFIER_CENTRAL = "central"
ORDER_RESET = "reset"

local json = require "json.json"
local redis = require("redis.redis")


-- generate publisher to clients
local pubRedisCon = redis:new()
local ok, err = pubRedisCon:connect("127.0.0.1", 6379)
if not ok then
	ngx.log(ngx.ERR, "failed to generate reset publisher:", err)
	ngx.exit(500)
	return
end

local order = {order = ORDER_RESET}

pubRedisCon:publish(IDENTIFIER_CENTRAL, json:encode(order))