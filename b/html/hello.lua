-- まだコンテキストの設計は行わない。 WebSocketへの介入ができるのか？というところに興味がある。

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

function dofile (filename)
    local f = assert(loadfile(filename))
    return f()
end

function pwd(  )
    ngx.say("here comes1!")
    ngx.say("here comes2!")

    -- ngx.shared.stats:incr("hits", 1) なんじゃろ。
    -- ngx.say(ngx.shared.stats:get("hits"))
end

-- dofile("")

pwd()


