local M = {[0] = "qdanshita"}
local mt = { __index = M }

-- receive message from downstream via ws then send it to upstream.
function fromDownstreamToUpstream(user_data)
	-- ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " established. token:", token, " to context:", UPSTREAM_IDENTIFIER)

	-- send connected message to upstream.
	local data = STATE_CONNECT..CONNECTION_ID..user_data
	addJobConn:addjob(UPSTREAM_IDENTIFIER, data, 0)
	
	-- start websocket serving.
	while true do
		local recv_data, typ, err = ws:recv_frame()

		if ws.fatal then
			ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " closing accidentially. ", err)
			local data = STATE_DISCONNECT_ACCIDT..CONNECTION_ID
			addJobConn:addjob(UPSTREAM_IDENTIFIER, data, 0)
			break
		end

		if not recv_data then
			ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " received empty data.")
			-- log only. do nothing.
		end

		if typ == "close" then
			ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " closing intentionally.")
			local data = STATE_DISCONNECT_INTENT..CONNECTION_ID
			addJobConn:addjob(UPSTREAM_IDENTIFIER, data, 0)
			
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
			local data = STATE_STRING_MESSAGE..CONNECTION_ID..recv_data
			addJobConn:addjob(UPSTREAM_IDENTIFIER, data, 0)

		elseif typ == "binary" then
			-- post binary data to central.
			local binData = STATE_BINARY_MESSAGE..CONNECTION_ID..recv_data
			addJobConn:addjob(UPSTREAM_IDENTIFIER, binData, 0)
		end
	end

	ws:send_close()
	ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " connection closed")


	receiveJobConn:close()
	addJobConn:close()

	ngx.exit(200)
end

-- pull message from upstream and send it to downstream via udp/ws.
function fromUpstreamToDownstream()
	local localWs = ws
	local from = "from"

	while true do
		-- receive message from disque queue, through CONNECTION_ID. 
		-- game context will send message via CONNECTION_ID.
		local res, err = receiveJobConn:getjob(from, CONNECTION_ID)
		
		--ngx.log(ngx.ERR, "receiving data:", #res)

		if not res then
			ngx.log(ngx.ERR, "err:", err)
			break
		else
			local datas = res[1]
			-- ngx.log(ngx.ERR, "client datas1:", datas[1])-- CONNECTION_ID
			-- ngx.log(ngx.ERR, "client datas2:", datas[2])-- messageId
			-- ngx.log(ngx.ERR, "client datas3:", datas[3])-- data
			local messageId = datas[2]
			local sendingData = datas[3]
			
			-- fastack to disque
			local ackRes, ackErr = receiveJobConn:fastack(messageId)
			if not ackRes then
				local data = STATE_DISCONNECT_DISQUE_ACKFAILED..CONNECTION_ID..the_id
				addJobConn:addjob(UPSTREAM_IDENTIFIER, data, 0)
				break
			end
			-- ngx.log(ngx.ERR, "messageId:", messageId, " ackRes:", ackRes)

			-- split data with continuation frame if need.
			if (DOWNSTREAM_MAX_PAYLOAD_LEN < #sendingData) then
				local count = math.floor(#sendingData / DOWNSTREAM_MAX_PAYLOAD_LEN)
				local rest = #sendingData % DOWNSTREAM_MAX_PAYLOAD_LEN

				local index = 1
				local failed = false
				for i = 1, count do
					-- send. from index to index + DOWNSTREAM_MAX_PAYLOAD_LEN.
					local continueData = string.sub(sendingData, index, index + DOWNSTREAM_MAX_PAYLOAD_LEN - 1)

					local bytes, err = localWs:send_continue(continueData)
					if not bytes then
						local data = STATE_DISCONNECT_DISQUE_ACCIDT_SENDFAILED..CONNECTION_ID..sendingData
						addJobConn:addjob(UPSTREAM_IDENTIFIER, data, 0)
						failed = true
						break
					end
					index = index + DOWNSTREAM_MAX_PAYLOAD_LEN
				end

				if failed then
					break
				end

				-- send rest data as binary.
				
				local lastData = string.sub(sendingData, index)

				local bytes, err = localWs:send_binary(lastData)
				if not bytes then
					local data = STATE_DISCONNECT_DISQUE_ACCIDT_SENDFAILED..CONNECTION_ID..sendingData
					addJobConn:addjob(UPSTREAM_IDENTIFIER, data, 0)
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
					local data = STATE_DISCONNECT_DISQUE_ACCIDT_SENDFAILED..CONNECTION_ID..sendingData
					addJobConn:addjob(UPSTREAM_IDENTIFIER, data, 0)
					break
				end
				--ngx.log(ngx.ERR, "receiving data5:", #res)
			end
		end
	end
	
	ngx.exit(200)
end


function M.connect(self, udp_port, user_data)
	-- udp socket for sending data to connected client via udp.
	do
		udpsock = ngx.socket.udp()
		udpsock:setpeername(UNIX_DOMAIN_SOCKET_PATH)

		local count = (#udp_port)
		dataHeader = count..udp_port
	end


	-- create upstream/downstream connection of disque.
	do
		local disque = require "disque.disque"

		-- downstream.
		receiveJobConn = disque:new()
		local ok, err = receiveJobConn:connect(DISQUE_IP, DISQUE_PORT)
		if not ok then
			ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " failed to generate receiveJob client")
			return
		end
		receiveJobConn:set_timeout(1000 * 60 * 60)

		-- upstream.
		addJobConn = disque:new()
		local ok, err = addJobConn:connect(DISQUE_IP, DISQUE_PORT)
		if not ok then
			ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " failed to generate addJob client")
			return
		end
		addJobConn:set_timeout(1000 * 60 * 60)
	end


	-- setup websocket client
	do
		local wsServer = require "ws.websocketServer"

		ws, wErr = wsServer:new{
			timeout = 10000000,--10000sec. never timeout from server.
			max_payload_len = DOWNSTREAM_MAX_PAYLOAD_LEN
		}

		if not ws then
			ngx.log(ngx.ERR, "connection:", CONNECTION_ID, " failed to new websocket:", wErr)
			return
		end
	end


	-- start receiving message from upstream & sending message to downstream.
	ngx.thread.spawn(fromUpstreamToDownstream)


	-- start receiving message from downstream & sending message to upstream.
	fromDownstreamToUpstream(user_data)
end

return M