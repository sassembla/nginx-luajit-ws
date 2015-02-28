-- このコンテキストを、クライアント側に対して送り込んで実行できるようにする。
-- nginxの再起動は御法度なので、実際にはここより下のコンテキストを叩き込む事になる。

-- 現状だと、コンパイルを経ないと反映されないので、読み込むところをどうにかして作らないといけない。接続先を求める感じにするかな。
-- あと実行スタイルを決めなければ。　open restyのやつを試そう。

-- それとluaの勉強も。 say以外のデバッグ方法を探さねば。
local sock = ngx.socket.udp()
-- local graphite_host = ngx.var.graphite_host
-- local graphite_port = ngx.var.graphite_port
-- local ok, err = sock:setpeername(graphite_host, tonumber(graphite_port))
-- if not ok then
--     ngx.say(err)
--     return
-- end

-- ngx.req.read_body()
-- local args, err = ngx.req.get_post_args()
-- if not args then
--     ngx.say(err)
--     return
-- end

-- local path = args.path
-- local value = args.value

-- local timestamp = os.time()
-- local data = table.concat({path, value, tostring(timestamp)}, " ")
-- local ok, err = sock:send(data)
-- if err then
--     ngx.say(err)
--     return
-- end

-- local ok, err = sock:close()
-- if not ok then
--     ngx.say(err)
--     return
-- end
ngx.say("here comes!")