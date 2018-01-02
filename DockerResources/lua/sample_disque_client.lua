-- get identity of game from url. e.g. http://somewhere/game_key -> game_key
local identity = string.gsub (ngx.var.uri, "/", "")

-- generate identity of queue for target context.
IDENTIFIER_CONTEXT = identity .. "_context"


STATE_CONNECT			= 1
STATE_STRING_MESSAGE	= 2
STATE_BINARY_MESSAGE	= 3
STATE_DISCONNECT_INTENT	= 4
STATE_DISCONNECT_ACCIDT = 5
STATE_DISCONNECT_DISQUE_ACKFAILED = 6
STATE_DISCONNECT_DISQUE_ACCIDT_SENDFAILED = 7



local the_id = ngx.req.get_headers()["id"]
if not the_id then
	the_id = "_empty_"
end



-- receive global udp target port.
local u_port = ngx.req.get_headers()["param"]
if not u_port then
	ngx.log(ngx.ERR, "no param.")
	return
end


-- udp socket for sending data to connected client via udp.
local udpsock = ngx.socket.udp()
local dataHeader = ""

do
	local ok, err = udpsock:setpeername("unix:/tmp/go-udp-server")
	-- ngx.log(ngx.ERR, "udp con ok:", ok, " err:", err)

	local count = (#u_port + 1) -- add length of :
	dataHeader = count..u_port
	
	-- test send.
	-- local ok, err = udpsock:send(dataHeader.."the data")
end





-- create upstream/downstream by disque.
disqueIp = "127.0.0.1"
disquePort = 7711

-- setup Disque get-add
local disque = require "disque.disque"

-- connectionId is nginx's request id. that len is 32 + 4.
local connectionId = ngx.var.request_id .. "0000"

receiveJobConn = disque:new()
local ok, err = receiveJobConn:connect(disqueIp, disquePort)
if not ok then
	ngx.log(ngx.ERR, "connection:", connectionId, " failed to generate receiveJob client")
	return
end

receiveJobConn:set_timeout(1000 * 60 * 60)


addJobCon = disque:new()
local ok, err = addJobCon:connect(disqueIp, disquePort)
if not ok then
	ngx.log(ngx.ERR, "connection:", connectionId, " failed to generate addJob client")
	return
end






local maxLen = 1024 -- 1k

-- setup websocket client
local wsServer = require "ws.websocketServer"

ws, wErr = wsServer:new{
	timeout = 10000000,-- this should be set good value.
	max_payload_len = maxLen
}

if not ws then
	ngx.log(ngx.ERR, "connection:", connectionId, " failed to new websocket:", wErr)
	return
end




function connectWebSocket()
	-- start receiving message from context.
	ngx.thread.spawn(contextReceiving)

	-- ngx.log(ngx.ERR, "connection:", connectionId, " established. the_id:", the_id, " to context:", IDENTIFIER_CONTEXT)

	-- send connected to gameContext.
	local data = STATE_CONNECT..connectionId..the_id
	addJobCon:addjob(IDENTIFIER_CONTEXT, data, 0)
	
	-- start websocket serving.
	while true do
		local recv_data, typ, err = ws:recv_frame()

		if ws.fatal then
			ngx.log(ngx.ERR, "connection:", connectionId, " closing accidentially. ", err)
			local data = STATE_DISCONNECT_ACCIDT..connectionId..the_id
			addJobCon:addjob(IDENTIFIER_CONTEXT, data, 0)
			break
		end

		if not recv_data then
			ngx.log(ngx.ERR, "connection:", connectionId, " received empty data.")
			-- log only. do nothing.
		end

		if typ == "close" then
			ngx.log(ngx.ERR, "connection:", connectionId, " closing intentionally.")
			local data = STATE_DISCONNECT_INTENT..connectionId..the_id
			addJobCon:addjob(IDENTIFIER_CONTEXT, data, 0)
			
			-- start close.
			break
		elseif typ == "ping" then
			local bytes, err = ws:send_pong(recv_data)
			-- ngx.log(ngx.ERR, "connection:", serverId, " ping received.")
			if not bytes then

				ngx.log(ngx.ERR, "connection:", serverId, " failed to send pong: ", err)
				break
			end

		elseif typ == "pong" then
			ngx.log(ngx.INFO, "client ponged")

		elseif typ == "text" then
			-- post message to central.
			local data = STATE_STRING_MESSAGE..connectionId..recv_data
			addJobCon:addjob(IDENTIFIER_CONTEXT, data, 0)

		elseif typ == "binary" then
			-- post binary data to central.
			local binData = STATE_BINARY_MESSAGE..connectionId..recv_data
			addJobCon:addjob(IDENTIFIER_CONTEXT, binData, 0)
		end
	end

	ws:send_close()
	ngx.log(ngx.ERR, "connection:", connectionId, " connection closed")

	addJobCon:close()
	receiveJobConn:close()
	ngx.exit(200)
end

-- loop for receiving messages from downstream.
function contextReceiving ()
	local localWs = ws
	local localMaxLen = maxLen
	while true do
		-- receive message from disque queue, through connectionId. 
		-- game context will send message via connectionId.
		local res, err = receiveJobConn:getjob("from", connectionId)
		
		--ngx.log(ngx.ERR, "receiving data:", #res)

		if not res then
			ngx.log(ngx.ERR, "err:", err)
			break
		else
			local datas = res[1]
			-- ngx.log(ngx.ERR, "client datas1:", datas[1])-- connectionId
			-- ngx.log(ngx.ERR, "client datas2:", datas[2])-- messageId
			-- ngx.log(ngx.ERR, "client datas3:", datas[3])-- data
			local messageId = datas[2]
			local sendingData = datas[3]
			
			-- fastack to disque
			local ackRes, ackErr = receiveJobConn:fastack(messageId)
			if not ackRes then
				local data = STATE_DISCONNECT_DISQUE_ACKFAILED..connectionId..the_id
				addJobCon:addjob(IDENTIFIER_CONTEXT, data, 0)
				break
			end
			-- ngx.log(ngx.ERR, "messageId:", messageId, " ackRes:", ackRes)

			-- split data with continuation frame if need.
			if (localMaxLen < #sendingData) then
				local count = math.floor(#sendingData / localMaxLen)
				local rest = #sendingData % localMaxLen

				local index = 1
				local failed = false
				for i = 1, count do
					-- send. from index to index + localMaxLen.
					local continueData = string.sub(sendingData, index, index + localMaxLen - 1)

					local bytes, err = localWs:send_continue(continueData)
					if not bytes then
						local data = STATE_DISCONNECT_DISQUE_ACCIDT_SENDFAILED..connectionId..sendingData
						addJobCon:addjob(IDENTIFIER_CONTEXT, data, 0)
						failed = true
						break
					end
					index = index + localMaxLen
				end

				if failed then
					break
				end

				-- send rest data as binary.
				
				local lastData = string.sub(sendingData, index)

				local bytes, err = localWs:send_binary(lastData)
				if not bytes then
					local data = STATE_DISCONNECT_DISQUE_ACCIDT_SENDFAILED..connectionId..sendingData
					addJobCon:addjob(IDENTIFIER_CONTEXT, data, 0)
					break
				end

			else
				-- send data via udp.
				if udpsock then
					local ok, err = udpsock:send(dataHeader..sendingData)
					--ngx.log(ngx.ERR, "udp send ok:", ok, " err:", err)
					if not ok then
						udpsock = nil
					end
				end
			
				-- send data to client via websocket.
				local bytes, err = localWs:send_binary(sendingData)
				
				if not bytes then
					local data = STATE_DISCONNECT_DISQUE_ACCIDT_SENDFAILED..connectionId..sendingData
					addJobCon:addjob(IDENTIFIER_CONTEXT, data, 0)
					break
				end
				--ngx.log(ngx.ERR, "receiving data5:", #res)
			end
		end
	end
	
	ngx.exit(200)
end



-- start receiving websocket data.
connectWebSocket()
