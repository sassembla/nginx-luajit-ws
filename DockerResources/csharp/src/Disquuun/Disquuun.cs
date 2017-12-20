using System;
using System.Collections.Generic;
using System.Net;

namespace DisquuunCore {
	public enum DisqueCommand {		
		ADDJOB,// queue_name job <ms-timeout> [REPLICATE <count>] [DELAY <sec>] [RETRY <sec>] [TTL <sec>] [MAXLEN <count>] [ASYNC]
		GETJOB,// [NOHANG] [TIMEOUT <ms-timeout>] [COUNT <count>] [WITHCOUNTERS] FROM queue1 queue2 ... queueN
		ACKJOB,// jobid1 jobid2 ... jobidN
		FASTACK,// jobid1 jobid2 ... jobidN
		WORKING,// jobid
		NACK,// <job-id> ... <job-id>
		INFO,
		HELLO,
		QLEN,// <queue-name>
		QSTAT,// <queue-name>
		QPEEK,// <queue-name> <count>
		ENQUEUE,// <job-id> ... <job-id>
		DEQUEUE,// <job-id> ... <job-id>
		DELJOB,// <job-id> ... <job-id>
		SHOW,// <job-id>
		QSCAN,// [COUNT <count>] [BUSYLOOP] [MINLEN <len>] [MAXLEN <len>] [IMPORTRATE <rate>]
		JSCAN,// [<cursor>] [COUNT <count>] [BUSYLOOP] [QUEUE <queue>] [STATE <state1> STATE <state2> ... STATE <stateN>] [REPLY all|id]
		PAUSE,// <queue-name> option1 [option2 ... optionN]
	}
	
	/**
		data structure for input.
	*/
	public class DisquuunInput	{
		public readonly DisqueCommand command;
		public readonly byte[] data;
		public readonly DisquuunSocketPool socketPool;
		
		public DisquuunInput (DisqueCommand command, byte[] data, DisquuunSocketPool socketPool) {
			this.command = command;
			this.data = data;
			this.socketPool = socketPool;
		}
	}
	

	/**
		data structure for result.
	*/
	public struct DisquuunResult {
		public ArraySegment<byte>[] bytesArray;
		
		public DisquuunResult (params ArraySegment<byte>[] bytesArray) {
			this.bytesArray = bytesArray;
		}
	}

	public enum DisquuunExecuteType {
		ASYNC,
		LOOP,
		PIPELINE
	}
	
	public class Disquuun {
		public readonly string connectionId;
		
		public readonly long bufferSize;
		public readonly IPEndPoint endPoint;
		
		public ConnectionState connectionState;
		
		
		private readonly Action<string> ConnectionOpened;
		private readonly Action<string, Exception> ConnectionFailed;
		
		private DisquuunSocketPool socketPool;
		
		public readonly int minConnectionCount;

		private object lockObject = new object();

		public enum ConnectionState {
			OPENING,
			OPENED,
			OPENED_RECOVERING,
			ALLCLOSING,
			ALLCLOSED
		}
		
		public Disquuun (
			string host,
			int port,
			long bufferSize,
			int minConnectionCount,
			Action<string> ConnectionOpenedAct=null,
			Action<string, Exception> ConnectionFailedAct=null
		) {
			this.connectionId = Guid.NewGuid().ToString();
			
			this.bufferSize = bufferSize;
			this.endPoint = new IPEndPoint(IPAddress.Parse(host), port);
			
			this.connectionState = ConnectionState.OPENING;

			/*
				ConnectionOpened handler treats all connections are opened.
			*/
			if (ConnectionOpenedAct != null) this.ConnectionOpened = ConnectionOpenedAct;
			else this.ConnectionOpened = conId => {};
			
			/*
				ConnectionFailed handler only treats connection error.
				
				other runtime errors will emit in API handler.
			*/
			if (ConnectionFailedAct != null) this.ConnectionFailed = ConnectionFailedAct;
			else this.ConnectionFailed = (info, e) => {};
			
			this.minConnectionCount = minConnectionCount;
			
			this.socketPool = new DisquuunSocketPool(minConnectionCount, this.OnSocketOpened, this.OnSocketConnectionFailed);

			this.socketPool.Connect(endPoint, bufferSize);
		}

		public int StackedCommandCount () {
			return socketPool.StackedCommandCount();
		}

		private void OnSocketOpened (DisquuunSocket source, string socketId) {
			if (connectionState != ConnectionState.OPENING) return;
			var availableSocketCount = socketPool.AvailableSocketNum();

			lock (lockObject) {
				if (connectionState != ConnectionState.OPENED && availableSocketCount == minConnectionCount) {
					connectionState = ConnectionState.OPENED;
					ConnectionOpened(connectionId);
				}
			}
		}
		
		private void OnSocketConnectionFailed (DisquuunSocket source, string info, Exception e) {
			UpdateState();
			if (ConnectionFailed != null) ConnectionFailed("OnSocketConnectionFailed:" + info, e); 
		}
		
		private ConnectionState UpdateState () {
			
			var availableSocketCount = socketPool.AvailableSocketNum();
				
			switch (connectionState) {
				case ConnectionState.OPENING: {
					if (availableSocketCount == minConnectionCount) connectionState = ConnectionState.OPENED;
					return connectionState;
				}
				case ConnectionState.OPENED: {
					if (availableSocketCount != minConnectionCount) connectionState = ConnectionState.OPENED_RECOVERING;
					return connectionState;
				}
				default: {
					if (availableSocketCount == minConnectionCount) connectionState = ConnectionState.OPENED; 
					break;
				}
			}
			return connectionState;
		}
		
		
		public ConnectionState State () {
			return UpdateState();
		}
		
		public void Disconnect () {
			connectionState = ConnectionState.ALLCLOSING;
			socketPool.Disconnect();
		}
		
		public int AvailableSocketNum () {
			return socketPool.AvailableSocketNum();
		}
		
		
		
		/*
			Disque API gateway
		*/
		public DisquuunInput AddJob (string queueName, byte[] data, int timeout=0, params object[] args) {
			var bytes = DisquuunAPI.AddJob(queueName, data, timeout, args);
			
			return new DisquuunInput(DisqueCommand.ADDJOB, bytes, socketPool);
		}
		
		public DisquuunInput GetJob (string[] queueIds, params object[] args) {
			var bytes = DisquuunAPI.GetJob(queueIds, args);
			
			return new DisquuunInput(DisqueCommand.GETJOB, bytes, socketPool);
		}
		
		public DisquuunInput AckJob (string[] jobIds) {
			var bytes = DisquuunAPI.AckJob(jobIds);
			
			return new DisquuunInput(DisqueCommand.ACKJOB, bytes, socketPool);
		}

		public DisquuunInput FastAck (string[] jobIds) {
			var bytes = DisquuunAPI.FastAck(jobIds);
			
			return new DisquuunInput(DisqueCommand.FASTACK, bytes, socketPool);
		}

		public DisquuunInput Working (string jobId) {
			var bytes = DisquuunAPI.Working(jobId);
			
			return new DisquuunInput(DisqueCommand.WORKING, bytes, socketPool);
		}

		public DisquuunInput Nack (string[] jobIds) {
			var bytes = DisquuunAPI.Nack(jobIds);
			
			return new DisquuunInput(DisqueCommand.NACK, bytes, socketPool);
		}

		public DisquuunInput Info () {
			var data = DisquuunAPI.Info();
			
			return new DisquuunInput(DisqueCommand.INFO, data, socketPool);
		}
		
		public DisquuunInput Hello () {
			var bytes = DisquuunAPI.Hello();

			return new DisquuunInput(DisqueCommand.HELLO, bytes, socketPool);
		}
		
		public DisquuunInput Qlen (string queueId) {
			var bytes = DisquuunAPI.Qlen(queueId);
			
			return new DisquuunInput(DisqueCommand.QLEN, bytes, socketPool);
		}
		
		public DisquuunInput Qstat (string queueId) {
			var bytes = DisquuunAPI.Qstat(queueId);
			
			return new DisquuunInput(DisqueCommand.QSTAT, bytes, socketPool);
		}
		
		public DisquuunInput Qpeek (string queueId, int count) {
			var bytes = DisquuunAPI.Qpeek(queueId, count);

			return new DisquuunInput(DisqueCommand.QPEEK, bytes, socketPool);
		}
		
		public DisquuunInput Enqueue (params string[] jobIds) {
			var bytes = DisquuunAPI.Enqueue(jobIds);
			
			return new DisquuunInput(DisqueCommand.ENQUEUE, bytes, socketPool);
		}
		
		public DisquuunInput Dequeue (params string[] jobIds) {
			var bytes = DisquuunAPI.Dequeue(jobIds);
			
			return new DisquuunInput(DisqueCommand.DEQUEUE, bytes, socketPool);
		}
		
		public DisquuunInput DelJob (params string[] jobIds) {
			var bytes = DisquuunAPI.DelJob(jobIds);
			
			return new DisquuunInput(DisqueCommand.DELJOB, bytes, socketPool);
		}
		
		public DisquuunInput Show (string jobId) {
			var bytes = DisquuunAPI.Show(jobId);
			
			return new DisquuunInput(DisqueCommand.SHOW, bytes, socketPool);
		}
		
		public DisquuunInput Qscan (params object[] args) {
			var bytes = DisquuunAPI.Qscan(args);
			
			return new DisquuunInput(DisqueCommand.QSCAN, bytes, socketPool);
		}
		
		public DisquuunInput Jscan (int cursor=0, params object[] args) {
			var bytes = DisquuunAPI.Jscan(cursor, args);
			
			return new DisquuunInput(DisqueCommand.JSCAN, bytes, socketPool);
		}
		
		public DisquuunInput Pause (string queueId, string option1, params string[] options) {
			var bytes = DisquuunAPI.Pause(queueId, option1, options);

			return new DisquuunInput(DisqueCommand.PAUSE, bytes, socketPool);
		}

		/*
			pipelines
		*/
		private List<List<DisquuunInput>> pipelineStack = new List<List<DisquuunInput>>();
		private int currentPipelineIndex = -1;

		public List<List<DisquuunInput>> Pipeline(params DisquuunInput[] disquuunInput) {
			lock (lockObject) {
				if (0 < disquuunInput.Length) {
					if (pipelineStack.Count == 0) currentPipelineIndex = 0;

					if (pipelineStack.Count < currentPipelineIndex + 1) pipelineStack.Add(new List<DisquuunInput>());
					pipelineStack[currentPipelineIndex].AddRange(disquuunInput);
				}
				return pipelineStack;
			}
		}

		public void RevolvePipeline () {
			lock (lockObject) {
				if (currentPipelineIndex == -1) return; 
				if (pipelineStack.Count == 0) return;
				
				if (0 < pipelineStack[currentPipelineIndex].Count) currentPipelineIndex++;
			}
		}
	}

	public static class DisquuunLogger {
		public static void Log (string message, bool write=false) {
			// TestLogger.Log(message, write);
		}
	}
	

	public class DisquuunSocketPool {
		private DisquuunSocket[] sockets;

		private StackSocket stackSocket;

		private object lockObject = new object();

		public DisquuunSocketPool (int connectionCount, Action<DisquuunSocket, string> OnSocketOpened, Action<DisquuunSocket, string, Exception> OnSocketConnectionFailed) {
			this.stackSocket = new StackSocket();
			this.sockets = new DisquuunSocket[connectionCount];
			for (var i = 0; i < sockets.Length; i++) this.sockets[i] = new DisquuunSocket(OnSocketOpened, this.OnReloaded, OnSocketConnectionFailed);
		}

		public void Connect (IPEndPoint endPoint, long bufferSize) {
			for (var i = 0; i < sockets.Length; i++) this.sockets[i].Connect(endPoint, bufferSize); 
		}

		public void Disconnect () {
			lock (lockObject) {
				foreach (var socket in sockets) socket.Disconnect();
			}
		}
		
		public StackSocket ChooseAvailableSocket () {
			lock (lockObject) {
				for (var i = 0; i < sockets.Length; i++) {
					var socket = sockets[i];
					if (socket.IsChoosable()) {
						socket.SetBusy();
						return socket;
					}
				}
				
				return stackSocket;
			}
		}

		public void OnReloaded (DisquuunSocket reloadedSocket) {
			lock (lockObject) {
				if (stackSocket.IsQueued()) {
					if (reloadedSocket.IsChoosable()) {
						reloadedSocket.SetBusy();

						var commandAndData = stackSocket.Dequeue(); 
						switch (commandAndData.executeType) {
							case DisquuunExecuteType.ASYNC: {
								reloadedSocket.Async(commandAndData.commands, commandAndData.data, commandAndData.Callback);
								return;
							}
							case DisquuunExecuteType.LOOP: {
								reloadedSocket.Loop(commandAndData.commands, commandAndData.data, commandAndData.Callback);
								return;
							}
							case DisquuunExecuteType.PIPELINE: {
								reloadedSocket.Execute(commandAndData.commands, commandAndData.data, commandAndData.Callback);
								return;
							}
						}
					}
				}
			}
		}

		public int AvailableSocketNum() {
			lock (lockObject) {
				var availableSocketCount = 0;
				for (var i = 0; i < sockets.Length; i++) {
					var socket = sockets[i];
					if (socket == null) continue;
					if (socket.IsChoosable()) availableSocketCount++;
				}
				return availableSocketCount;
			}
		}

		public int StackedCommandCount() {
			lock (lockObject) return stackSocket.QueueCount();
		}
	}
}
