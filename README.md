#nginx-lua-websocket-pubsuber

nginxでluaを使ってWebSocketを受け付け、出来るだけ依存を小さくpub-subとかフレームレート持てるように書いてみたテストベッド。

テストベッド言いたかっただけ。

依存しているものをなんもかんもとりあえず取り込む形にしている。
依存関係に関して見れたのは良かった。

以下、機能特性。

1. WebSocket接続
2. contextを持ちpub-subが可能(luaでなくても書ける)
3. contextとWebSocket接続が疎結合なので、接続保ったままcontextの更新が可能(単に別なだけ)


##requirement & dependency
* redis 2.8.9 (depends on pub/sub)
* this.(contains luajit, pcre, nginx_lua_mod, lua_redis_mod)
* Mac OS X(only tested on Mac. ha-ha)
 
 
##setup
1. start redis

	redis-server /usr/local/etc/redis.conf


1. start customized nginx
	
	sudo bin/sbin/nginx
	
1. initial request for nginx

	127.0.0.1:80/controlpoint
	
1. open testClient.html
	
	this html contains JS which connect to nginx with WebSocket. After connect, then send message to nginx automatically.
	
##reload context

1. kill current context by reset url
	
	127.0.0.1:80/reset

1. re request
	
	127.0.0.1:80/controlpoint

this structure will keep connection between client to nginx. can reload context only.

##single context for all websocket connections

context file is bin/lua/lib/context.lua

onFrame method is running 100times/sec.


	--[[]
		context for all connecting players.
		you can use local parameters and table(dictionary)s like local application.
	]]
	local M = {}

	connections = {}

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

	end

	return M

