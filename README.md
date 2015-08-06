#nginx-lua-websocket-pubsuber

![SS](/Doc/graph.png)

nginxでluaを使ってWebSocketを受け付け、出来るだけ依存を小さくpub-subとかフレームレート持てるように書いてみたテストベッド。

テストベッド言いたかっただけ。

依存しているものをなんもかんもとりあえず取り込む形にしている。
依存関係に関して見れたのは良かった。

以下、機能特性。

1. WebSocket接続
2. すべての接続がmessageQueueを介して一箇所のcontextに収束
3. contextはmessageQueueにアクセスできさえすれば要件を満たせる。どんな言語でも環境でも書けるはず
4. contextとWebSocket接続が疎結合なので、接続保ったままcontextの更新が可能(単に別なだけ)


##requirement & dependency
* redis 2.8.9 (depends on pub/sub as messageQueue)
* this.(contains luajit, pcre, nginx_lua_mod, lua_redis_mod)
* Only tested on Mac & Linux. ha-ha.
 
 
##build custom nginx
	sh build.sh

##run
test components are located like below.
![SS](/Doc/graph2.png)

1. start redis

		redis-server

1. start customized nginx
	
		sudo 1.7.10/sbin/nginx
	
1. add new gameContext to ngx.

		open addGameContext.html
	
1. add new client.

		open client.html
	


##single context for all websocket connections

context file is 1.7.10/lua/gameContext.lua

	--[[]
		game context for all connecting players implemented by lua.
		you can use local parameters and table(dictionary)s like local application.
	]]
	local context = {}


	local connections = {}
	local count = 0

	function context.onConnect(from, publish)
		ngx.log(ngx.ERR, "connect from:", from)
	end

	function context.onMessage(from, data, publish)
		-- do something here.
		ngx.log(ngx.ERR, "message from:", from, " data:", data)

		-- publish(data, to)
		-- publish(data, to1, to2, ,,,)
		-- publish(data)

		-- publish(data)
	end

	function context.onDisconnect(from, reason, publish)
		ngx.log(ngx.ERR, "disconnect from:", from, " reason:", reason)
	end

	function context.onUpdate(publish)
		if count % 100 == 0 then 
			ngx.log(ngx.ERR, "gameContext frame countUp:" .. count)
			publish("gameContext frame countUp:" .. count)
		end

		count = count + 1
	end

