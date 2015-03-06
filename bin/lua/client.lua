-- entrypoint for WebSocket connect.

-- グローバルなコンテキストで汚いけど実験。
local redis = require "redis.redis"

subscribeRedisCon = redis:new()
publishRedisCon = redis:new()

local server = require "websocket.server"

wb, wErr = server:new{
	timeout = 10000000,
	max_payload_len = 65535
}

if not wb then
	ngx.log(ngx.ERR, "failed to new websocket: ", wErr)
	return ngx.exit(444)
end


function connectWebSocket()
	-- 手段を纏めると、
	-- ・辞書でwbの保持 -> wbそのものは無理っぽい。どこで駄目になってるかはわかんないけど、値でないと無理なんだろう。
	-- 		sockだったら？ 駄目
	-- 		もっと小さい情報ってあるのかな、、っておもったが、まだかかりそう。
	-- ・redisでpub-sub
	-- 		ngx.thread.spawn でスレッド作って動かすとか出来そう。
	-- 		-> 出来た。
	-- ・wb内部でつかっているsocketのportみつけてそこに向かってフォーマットかけて送るコードを書く
	-- 		->面倒ぽい、、redisの実装を書き替えてcontextglobalなnginxモジュール作るか。
	-- のどれか。redisのpub-subにはあんまり頼りたくない。

	local ok, err = subscribeRedisCon:connect("127.0.0.1", 6379)
	if not ok then
		ngx.log(ngx.ERR, "failed to generate subscriver")
		return
	end

	local ok, err = subscribeRedisCon:subscribe("str")
	if not ok then
		ngx.log(ngx.ERR, "failed to start subscriver")
		return
	end


	local ok, err = publishRedisCon:connect("127.0.0.1", 6379)
	if not ok then
		ngx.log(ngx.ERR, "failed to generate publisher")
		return
	end

	-- start subscribe
	ngx.thread.spawn(subscribe)


	-- start websocket serving
	while true do
		local data, typ, err = wb:recv_frame()

		if wb.fatal then
			ngx.log(ngx.ERR, "failed to receive frame: ", err)
			return ngx.exit(444)
		end
		if not data then
			local bytes, err = wb:send_ping()
			if not bytes then
				ngx.log(ngx.ERR, "failed to send ping: ", err)
				return ngx.exit(444)
			end
		elseif typ == "close" then break
		elseif typ == "ping" then
			local bytes, err = wb:send_pong()
			if not bytes then
				ngx.log(ngx.ERR, "failed to send pong: ", err)
				return ngx.exit(444)
			end
		elseif typ == "pong" then
			ngx.log(ngx.INFO, "client ponged")

		elseif typ == "text" then
			publishRedisCon:publish("str", "test!")
		end
	end


	wb:send_close()
end



function subscribe ()
	while true do
		local res, err = subscribeRedisCon:read_reply()
		if not res then
			ngx.log(ngx.ERR, "redis subscribe read error:", err)
		else
			-- ngx.log(ngx.ERR, "4!", res)
			for i,v in ipairs(res) do
				ngx.log(ngx.ERR, "i:", i, " v:", v)
			end

			-- send message with WebSocket for all subscribers.
			local bytes, err = wb:send_text("ここ、固定データから可変データに変えればそれで終わり")

			if not bytes then
				ngx.log(ngx.ERR, "failed to send text:", err)
				return ngx.exit(444)
			end

		end
	end
end


-- 辞書で維持できるのはコンテキストを超えられるものだけ = value系のみなので、今回の用途には使えない。
function dictor (sock)
	local dogs = ngx.shared.dogs
	local val0 = dogs:get("Jim")
	ngx.log(ngx.ERR, "val0:", val0)

	if val0 then
		local val = dogs:get("Jim")
		ngx.log(ngx.ERR, " val:", val)
	else
		ngx.log(ngx.ERR, " set!")
		dogs:set("Jim", sock)

		local val2 = dogs:get("Jim")
		ngx.log(ngx.ERR, " val2:", val2)
	end
end


connectWebSocket()
