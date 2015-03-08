#nginx-lua-websocket-pubsuber

nginxでluaを使ってWebSocketを受け付け、出来るだけ依存を小さくpub-subとかフレームレート持てるように書いてみたテストベッド。

テストベッド言いたかっただけ。

依存しているものをなんもかんもとりあえず取り込む形にしている。
依存関係に関して見れたのは良かった。

##requirement & dependency
* redis 2.8.9 (depends on pub/sub)
* this.
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
	
	
##all websocket context

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

