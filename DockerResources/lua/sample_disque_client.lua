-- get identity of game from url. e.g. http://somewhere/game_key -> game_key_context.
UPSTREAM_IDENTIFIER = string.gsub(ngx.var.uri, "/", "") .. "_context"

-- message type definitions.
STATE_CONNECT           = 1
STATE_STRING_MESSAGE    = 2
STATE_BINARY_MESSAGE    = 3
STATE_DISCONNECT_INTENT = 4
STATE_DISCONNECT_ACCIDT = 5
STATE_DISCONNECT_DISQUE_ACKFAILED = 6
STATE_DISCONNECT_DISQUE_ACCIDT_SENDFAILED = 7


---- SETTINGS ----

-- upstream/downstream queue.
DISQUE_IP = "127.0.0.1"
DISQUE_PORT = 7711

-- CONNECTION_ID is nginx's request id. that len is 32. guidv4 length is 36, add four "0".
CONNECTION_ID = ngx.var.request_id .. "0000"

-- go unix domain socket path.
UNIX_DOMAIN_SOCKET_PATH = "unix:/tmp/go-udp-server"

-- max size of downstream message.
DOWNSTREAM_MAX_PAYLOAD_LEN = 1024


---- REQUEST HEADER PARAMS ----


local token = ngx.req.get_headers()["token"]
if not token then
	ngx.log(ngx.ERR, "no token.")
	return
end


local udp_port = ngx.req.get_headers()["param"]
if not udp_port then
	ngx.log(ngx.ERR, "no param.")
	return
end

---- POINT BEFORE CONNECT ----

-- redis example.
-- このままだと通信単位でredisアクセスが発生しちゃうので、このブロック内で、なんらかのtokenチェックをやるとかするとなお良い。このサーバにくるはずなら〜とかそういう要素で。
if false then
	local redis = require "redis.redis"
	local redisConn = redis:new()
	local ok, err = redisConn:connect("127.0.0.1", 6379)

	if not ok then
		ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " failed to generate redis client. err:", err)
		return
	end

	-- トークンをキーにして取得
	local res, err = redisConn:get(token)
	
	-- キーがkvsになかったら認証失敗として終了
	if not res then
		-- no key found.
		ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " failed to authenticate. no token found in kvs.")

		-- 切断
		redisConn:close()
		ngx.exit(200)
		return
	elseif res == ngx.null then
		-- no value found.
		ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " failed to authenticate. token is nil.")

		-- 切断
		redisConn:close()
		ngx.exit(200)
		return
	end

	-- delete got key.
	local ok, err = redisConn:del(token)

	-- 切断
	redisConn:close()

	-- 変数にセット、パラメータとして渡す。
	user_data = res
else
	user_data = token
end

-- ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " user_data:", user_data)

---- CONNECT ----

local qd = require "qdanshita.qdanshita"
qd:connect(udp_port, user_data)