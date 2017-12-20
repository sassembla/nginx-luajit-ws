using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace DisquuunCore {
    public static class DisquuunAPI {
		/*
			disque protocol symbols
		*/
		public enum CommandString {
			Error = '-',
			Status = '+',
			Bulk = '$',
			MultiBulk = '*',
			Int = ':'
		}
		
		/*
			chars
		*/
		public const char CharError = (char)CommandString.Error;
		public const char CharStatus = (char)CommandString.Status;
		public const char CharBulk = (char)CommandString.Bulk;
		public const char CharMultiBulk = (char)CommandString.MultiBulk;
		public const char CharInt = (char)CommandString.Int;
		public const string CharEOL = "\r\n";
		
		
		public const string DISQUE_GETJOB_KEYWORD_FROM = "FROM";
		
		/*
			bytes
		*/
		public const byte ByteError		= 45;
		public const byte ByteStatus	= 43;
		public const byte ByteBulk		= 36;
		public const byte ByteMultiBulk	= 42;
		public const byte ByteInt		= 58;
		public static readonly byte ByteCR = Convert.ToByte('\r');
		public static readonly byte ByteLF = Convert.ToByte('\n');
		
		private static byte[] BytesMultiBulk = new byte[]{ByteMultiBulk};
		private static byte[] BytesCRLF = new byte[]{ByteCR, ByteLF};
		private static byte[] BytesBulk = new byte[]{ByteBulk};
	
		
		/*
			Disque APIs.
		*/
		public static byte[] AddJob (string queueName, byte[] data, int timeout=0, params object[] args) {
			// ADDJOB queue_name job <ms-timeout> 
			// [REPLICATE <count>] [DELAY <sec>] [RETRY <sec>] [TTL <sec>] [MAXLEN <count>] [ASYNC]
			
			var newArgs = new object[1 + args.Length];
			newArgs[0] = timeout;
			for (var i = 1; i < newArgs.Length; i++) newArgs[i] = args[i-1];
			
			using (var byteBuffer = new MemoryStream()) {
				var contentCount = 1;// count of command.
				
				if (!string.IsNullOrEmpty(queueName)) {
					contentCount++;
				}

				if (0 < data.Length) {
					contentCount++;
				}

				if (0 < newArgs.Length) {
					contentCount = contentCount + newArgs.Length;
				}

				// "*" + contentCount.ToString() + "\r\n"
				{
					var contentCountBytes = Encoding.UTF8.GetBytes(contentCount.ToString());
					
					byteBuffer.Write(BytesMultiBulk, 0, BytesMultiBulk.Length);
					byteBuffer.Write(contentCountBytes, 0, contentCountBytes.Length);
					byteBuffer.Write(BytesCRLF, 0, BytesCRLF.Length);
				}

				// "$" + cmd.Length + "\r\n" + cmd + "\r\n"
				{
					var commandBytes = Encoding.UTF8.GetBytes(DisqueCommand.ADDJOB.ToString());
					var commandCountBytes = Encoding.UTF8.GetBytes(DisqueCommand.ADDJOB.ToString().Length.ToString());
				
					byteBuffer.Write(BytesBulk, 0, BytesBulk.Length);
					byteBuffer.Write(commandCountBytes, 0, commandCountBytes.Length);
					byteBuffer.Write(BytesCRLF, 0, BytesCRLF.Length);
					byteBuffer.Write(commandBytes, 0, commandBytes.Length);
					byteBuffer.Write(BytesCRLF, 0, BytesCRLF.Length);
				}

				// "$" + queueId.Length + "\r\n" + queueId + "\r\n"
				if (!string.IsNullOrEmpty(queueName)) {
					var queueIdBytes = Encoding.UTF8.GetBytes(queueName);
					var queueIdCountBytes = Encoding.UTF8.GetBytes(queueName.Length.ToString());
					
					byteBuffer.Write(BytesBulk, 0, BytesBulk.Length);
					byteBuffer.Write(queueIdCountBytes, 0, queueIdCountBytes.Length);
					byteBuffer.Write(BytesCRLF, 0, BytesCRLF.Length);
					byteBuffer.Write(queueIdBytes, 0, queueIdBytes.Length);
					byteBuffer.Write(BytesCRLF, 0, BytesCRLF.Length);
				}

				// "$" + data.Length + "\r\n" + data + "\r\n"
				if (0 < data.Length) {
					var dataCountBytes = Encoding.UTF8.GetBytes(data.Length.ToString());
					
					byteBuffer.Write(BytesBulk, 0, BytesBulk.Length);
					byteBuffer.Write(dataCountBytes, 0, dataCountBytes.Length);
					byteBuffer.Write(BytesCRLF, 0, BytesCRLF.Length);
					byteBuffer.Write(data, 0, data.Length);
					byteBuffer.Write(BytesCRLF, 0, BytesCRLF.Length);
				}

				// "$" + option.Length + "\r\n" + option + "\r\n"
				if (0 < newArgs.Length) {
					foreach (var option in newArgs) {
						var optionBytes = Encoding.UTF8.GetBytes(option.ToString());
						var optionCountBytes = Encoding.UTF8.GetBytes(optionBytes.Length.ToString());
					
						byteBuffer.Write(BytesBulk, 0, BytesBulk.Length);
						byteBuffer.Write(optionCountBytes, 0, optionCountBytes.Length);
						byteBuffer.Write(BytesCRLF, 0, BytesCRLF.Length);
						byteBuffer.Write(optionBytes, 0, optionBytes.Length);
						byteBuffer.Write(BytesCRLF, 0, BytesCRLF.Length);
					}	
				}
				
				return byteBuffer.ToArray();
			}
		}
		
		public static byte[] GetJob (string[] queueIds, object[] args) {
			// [NOHANG] [TIMEOUT <ms-timeout>] [COUNT <count>] [WITHCOUNTERS] 
			// FROM queue1 queue2 ... queueN
			var parameters = new object[args.Length + 1 + queueIds.Length];
			for (var i = 0; i < parameters.Length; i++) {
				if (i < args.Length) {
					parameters[i] = args[i];
					continue;
				}
				if (i == args.Length) {
					parameters[i] = DISQUE_GETJOB_KEYWORD_FROM;
					continue;
				}
				parameters[i] = queueIds[i - (args.Length + 1)];
			}
			// foreach (var i in parameters) {
			// 	Log("i:" + i);
			// }
			return ToBytes(DisqueCommand.GETJOB, parameters);
		}
		
		public static byte[] AckJob (string[] jobIds) {
			// jobid1 jobid2 ... jobidN
			return ToBytes(DisqueCommand.ACKJOB, jobIds);
		}

		public static byte[] FastAck (string[] jobIds) {
			// jobid1 jobid2 ... jobidN
			return ToBytes(DisqueCommand.FASTACK, jobIds);
		}

		public static byte[] Working (string jobId) {
			// jobid
			return ToBytes(DisqueCommand.WORKING, jobId);
		}

		public static byte[] Nack (string[] jobIds) {
			// <job-id> ... <job-id>
			return ToBytes(DisqueCommand.NACK, jobIds);
		}
		
		public static byte[] Info () {
			return ToBytes(DisqueCommand.INFO);
		}
		
		public static byte[] Hello () {
			return ToBytes(DisqueCommand.HELLO);
		}
		
		public static byte[] Qlen (string queueId) {
			return ToBytes(DisqueCommand.QLEN, queueId);
		}
		
		public static byte[] Qstat (string queueId) {
			return ToBytes(DisqueCommand.QSTAT, queueId);
		}
		
		public static byte[] Qpeek (string queueId, int count) {
			return ToBytes(DisqueCommand.QPEEK, queueId, count);
		}
		
		public static byte[] Enqueue (string[] jobIds) {
			return ToBytes(DisqueCommand.ENQUEUE, jobIds);
		}
		
		public static byte[] Dequeue (string[] jobIds) {
			return ToBytes(DisqueCommand.DEQUEUE, jobIds);
		}
		
		public static byte[] DelJob (string[] jobIds) {
			return ToBytes(DisqueCommand.DELJOB, jobIds);
		}
		
		public static byte[] Show (string jobId) {
			return ToBytes(DisqueCommand.SHOW, jobId);
		}
		
		public static byte[] Qscan (object[] args) {
			return ToBytes(DisqueCommand.QSCAN, args);
		}
		
		public static byte[] Jscan (int cursor, object[] args) {
			return ToBytes(DisqueCommand.JSCAN, cursor, args);
		}
		
		public static byte[] Pause (string queueId, string option1, string[] options) {
			return ToBytes(DisqueCommand.JSCAN, queueId, option1, options);
		}
		
		
		private static byte[] ToBytes (DisqueCommand commandEnum, params object[] args) {
			int length = 1 + args.Length;
			
			var command = commandEnum.ToString();
			string strCommand;
			
			{
				StringBuilder sb = new StringBuilder();
				sb.Append(CharMultiBulk).Append(length).Append(CharEOL);
				
				sb.Append(CharBulk).Append(Encoding.UTF8.GetByteCount(command)).Append(CharEOL).Append(command).Append(CharEOL);
				
				foreach (var arg in args) {
					var str = String.Format(CultureInfo.InvariantCulture, "{0}", arg);
					sb.Append(CharBulk)
						.Append(Encoding.UTF8.GetByteCount(str))
						.Append(CharEOL)
						.Append(str)
						.Append(CharEOL);
				}
				strCommand = sb.ToString();
			}
			
			byte[] bytes = Encoding.UTF8.GetBytes(strCommand.ToCharArray());
			
			return bytes;
		}
		
		public struct ScanResult {
			public readonly int cursor;
			public readonly bool isDone;
			public readonly DisquuunResult[] data;
			
			public ScanResult (int cursor, bool isDone, DisquuunResult[] data) {
				this.cursor = cursor;
				this.isDone = isDone;
				this.data = data;
			}
			public ScanResult (bool dummy=false) {
				this.cursor = -1;
				this.isDone = false;
				this.data = null;
			}
		}
		
		public static ScanResult ScanBuffer (DisqueCommand command, byte[] sourceBuffer, int fromCursor, long length, string socketId) {
			var cursor = fromCursor;
			
			switch (command) {
				case DisqueCommand.ADDJOB: {
					switch (sourceBuffer[cursor]) {
						// case ByteError: {
							// -
							// var lineEndCursor = ReadLine(sourceBuffer, cursor);
							// cursor = cursor + 1;// add header byte size = 1.
							
							// if (Failed != null) {
							// 	var errorStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor - cursor);
							// 	// Disquuun.Log("errorStr:" + errorStr);
							// 	Failed(currentCommand, errorStr);
							// }
							
							// cursor = lineEndCursor + 2;// CR + LF
							// break;
						// }
						case ByteStatus: {
							// + count
							var lineEndCursor = ReadLine(sourceBuffer, cursor, length);
							if (lineEndCursor == -1) return new ScanResult(false);
							cursor = cursor + 1;// add header byte size = 1.
							
							var countBuffer = new ArraySegment<byte>(sourceBuffer, cursor, lineEndCursor - cursor);
							
							cursor = lineEndCursor + 2;// CR + LF

							return new ScanResult(cursor, true, new DisquuunResult[]{new DisquuunResult(countBuffer)});
						}
					}
					break;
				}
				case DisqueCommand.GETJOB: {
					switch (sourceBuffer[cursor]) {
						case ByteMultiBulk: {
							DisquuunResult[] jobDatas = null;
							{
								// * count.
								var lineEndCursor = ReadLine(sourceBuffer, cursor, length);
								if (lineEndCursor == -1) return new ScanResult(false);
								
								cursor = cursor + 1;// add header byte size = 1.
								
								var bulkCountStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor - cursor);
								// TestLogger.Log("bulkCountStr:" + bulkCountStr);
								var bulkCountNum = Convert.ToInt32(bulkCountStr);
								
								cursor = lineEndCursor + 2;// CR + LF
								
								
								// trigger when GETJOB NOHANG
								if (bulkCountNum < 0) return new ScanResult(cursor, true, new DisquuunResult[]{});
								
								
								jobDatas = new DisquuunResult[bulkCountNum];
								for (var i = 0; i < bulkCountNum; i++) {
									var itemCount = 0;
									
									{
										// * count.
										var lineEndCursor2 = ReadLine(sourceBuffer, cursor, length);
										if (lineEndCursor2 == -1) return new ScanResult(false);
									
										cursor = cursor + 1;// add header byte size = 1.
										
										var bulkCountStr2 = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor2 - cursor);
										
										itemCount = Convert.ToInt32(bulkCountStr2);
										// Disquuun.Log("itemCount:" + itemCount);
										
										cursor = lineEndCursor2 + 2;// CR + LF
									}
									
									// queueName
									{
										// $ count.
										var lineEndCursor3 = ReadLine(sourceBuffer, cursor, length);
										if (lineEndCursor3 == -1) return new ScanResult(false);
										
										cursor = cursor + 1;// add header byte size = 1											
										
										var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor3 - cursor);
										var strNum = Convert.ToInt32(countStr);
										
										cursor = lineEndCursor3 + 2;// CR + LF
										
										// $ bulk.
										if (ShortageOfReadableLength(sourceBuffer, cursor, strNum)) return new ScanResult(false);
										// var nameStr = Encoding.UTF8.GetString(sourceBuffer, cursor, strNum);
										// Disquuun.Log("nameStr:" + nameStr);
										
										cursor = cursor + strNum + 2;// CR + LF
									}
									
									// jobId
									ArraySegment<byte> jobIdBytes;
									{
										// $ count.
										var lineEndCursor3 = ReadLine(sourceBuffer, cursor, length);
										if (lineEndCursor3 == -1) return new ScanResult(false);
										
										cursor = cursor + 1;// add header byte size = 1.
										
										var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor3 - cursor);
										var strNum = Convert.ToInt32(countStr);
										// Disquuun.Log("id strNum:" + strNum);
										
										cursor = lineEndCursor3 + 2;// CR + LF
										
										
										// $ bulk.
										if (ShortageOfReadableLength(sourceBuffer, cursor, strNum)) return new ScanResult(false);
										jobIdBytes = new ArraySegment<byte>(sourceBuffer, cursor, strNum);
										// var jobIdStr = Encoding.UTF8.GetString(jobIdBytes);
										// Disquuun.Log("jobIdStr:" + jobIdStr);
										
										cursor = cursor + strNum + 2;// CR + LF
									}
									
									
									// jobData
									ArraySegment<byte> dataBytes;
									{
										// $ count.
										var lineEndCursor3 = ReadLine(sourceBuffer, cursor, length);
										if (lineEndCursor3 == -1) return new ScanResult(false);
										
										cursor = cursor + 1;// add header byte size = 1.
										
										var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor3 - cursor);
										var strNum = Convert.ToInt32(countStr);
										
										cursor = lineEndCursor3 + 2;// CR + LF
										
										
										// $ bulk.
										if (ShortageOfReadableLength(sourceBuffer, cursor, strNum)) return new ScanResult(false);
										dataBytes = new ArraySegment<byte>(sourceBuffer, cursor, strNum);
										
										cursor = cursor + strNum + 2;// CR + LF
									}
									
									// no withcounters response.
									if (itemCount == 3) {	
										jobDatas[i] = new DisquuunResult(jobIdBytes, dataBytes);
										// cursor = cursor + 2;// CR + LF
										continue;
									}
									
									// withcounters response.
									if (itemCount == 7) {
										ArraySegment<byte> nackCountBytes;
										{
											// $
											var lineEndCursor3 = ReadLine(sourceBuffer, cursor, length);
											if (lineEndCursor3 == -1) return new ScanResult(false);
											
											cursor = cursor + 1;// add header byte size = 1.
											
											var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor3 - cursor);
											var strNum = Convert.ToInt32(countStr);
											// Disquuun.Log("data strNum:" + strNum);
											
											cursor = lineEndCursor3 + 2;// CR + LF
											
											// ignore params. 
										
											cursor = cursor + strNum + 2;// CR + LF

											// :
											var lineEndCursor4 = ReadLine(sourceBuffer, cursor, length);
											if (lineEndCursor4 == -1) return new ScanResult(false);
											cursor = cursor + 1;// add header byte size = 1.
											
											nackCountBytes = new ArraySegment<byte>(sourceBuffer, cursor, lineEndCursor4 - cursor);
											
											cursor = lineEndCursor4 + 2;// CR + LF
										}
										
										ArraySegment<byte> additionalDeliveriesCountBytes;
										{
											// $
											var lineEndCursor3 = ReadLine(sourceBuffer, cursor, length);
											if (lineEndCursor3 == -1) return new ScanResult(false);
											cursor = cursor + 1;// add header byte size = 1.
											
											var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor3 - cursor);
											var strNum = Convert.ToInt32(countStr);
											// Disquuun.Log("data strNum:" + strNum);
											
											cursor = lineEndCursor3 + 2;// CR + LF
											
											// ignore params. 
										
											cursor = cursor + strNum + 2;// CR + LF
										
											// :
											var lineEndCursor4 = ReadLine(sourceBuffer, cursor, length);
											if (lineEndCursor4 == -1) return new ScanResult(false);
											cursor = cursor + 1;// add header byte size = 1.
											
											additionalDeliveriesCountBytes = new ArraySegment<byte>(sourceBuffer, cursor, lineEndCursor4 - cursor);
											
											jobDatas[i] = new DisquuunResult(jobIdBytes, dataBytes, nackCountBytes, additionalDeliveriesCountBytes);
											
											cursor = lineEndCursor4 + 2;// CR + LF
										}
									}
								}
							}
							
							if (jobDatas != null && 0 < jobDatas.Length) return new ScanResult(cursor, true, jobDatas);
							break;
						}
						// case ByteError: {
						// 	// -
						// 	Disquuun.Log("-");
						// 	throw new Exception("GetJob error.");
						// 	// var lineEndCursor = ReadLine2(sourceBuffer, cursor, length);
						// 	// cursor = cursor + 1;// add header byte size = 1.
							
						// 	// if (Failed != null) {
						// 	// 	var errorStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor - cursor);
						// 	// 	// Disquuun.Log("errorStr:" + errorStr);
						// 	// 	Failed(currentCommand, errorStr);
						// 	// }
							
						// 	// cursor = lineEndCursor + 2;// CR + LF
						// 	break;
						// }
					}
					break;
				}
				case DisqueCommand.ACKJOB:
				case DisqueCommand.FASTACK: {
					switch (sourceBuffer[cursor]) {
						case ByteInt: {
							// : count.
							var lineEndCursor = ReadLine(sourceBuffer, cursor, length);
							if (lineEndCursor == -1) return new ScanResult(false); 
							cursor = cursor + 1;// add header byte size = 1.
							
							// var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor - cursor);
							// Disquuun.Log("countStr:" + countStr);
							
							var countBuffer = new ArraySegment<byte>(sourceBuffer, cursor, lineEndCursor - cursor);
							
							var byteData = new DisquuunResult(countBuffer);
							
							cursor = lineEndCursor + 2;// CR + LF
							return new ScanResult(cursor, true, new DisquuunResult[]{byteData});
						}
						// case ByteError: {
						// 	// -
						// 	var lineEndCursor = ReadLine(sourceBuffer, cursor);
						// 	cursor = cursor + 1;// add header byte size = 1.
							
						// 	if (Failed != null) {
						// 		var errorStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor - cursor);
						// 		// Disquuun.Log("errorStr:" + errorStr);
						// 		Failed(currentCommand, errorStr);
						// 	}
						// 	cursor = lineEndCursor + 2;// CR + LF
						// 	break;
						// }
					}
					break;
				}
				case DisqueCommand.INFO: {
					switch (sourceBuffer[cursor]) {
						case ByteBulk: {
							
							var countNum = 0;
							{// readbulk count.
								// $
								var lineEndCursor = ReadLine(sourceBuffer, cursor, length);
								if (lineEndCursor == -1) return new ScanResult(false);
								cursor = cursor + 1;// add header byte size = 1.
								
								var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor - cursor);
								countNum = Convert.ToInt32(countStr);
								
								cursor = lineEndCursor + 2;// CR + LF
							}
							
							{// readbulk string.
								if (ShortageOfReadableLength(sourceBuffer, cursor, countNum)) return new ScanResult(false);
								
								var newBuffer = new ArraySegment<byte>(sourceBuffer, cursor, countNum);
								
								cursor = cursor + countNum + 2;// CR + LF
								
								return new ScanResult(cursor, true, new DisquuunResult[]{new DisquuunResult(newBuffer)});
							}
						}
					}
					break;
				}
				case DisqueCommand.HELLO: {
					switch (sourceBuffer[cursor]) {
						case ByteMultiBulk: {
							ArraySegment<byte> version;
							ArraySegment<byte> thisNodeId;
							List<ArraySegment<byte>> nodeIdsAndInfos = new List<ArraySegment<byte>>();
							/*
								:*3
									:1 version [0][0]
									
									$40 this node ID [0][1]
										002698920b158ba29ff8d41d3e5303ceaf0e8d45
									
									*4 [1~n][0~3]
										$40
											002698920b158ba29ff8d41d3e5303ceaf0e8d45
										
										$0
											""
										
										$4
											7711
										
										$1
											1
							*/
							
							{
								// *
								var lineEndCursor = ReadLine(sourceBuffer, cursor, length);
								if (lineEndCursor == -1) return new ScanResult(false);
								cursor = cursor + 1;// add header byte size = 1.

								// var bulkCountStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor - cursor);
								// Disquuun.Log("bulkCountStr:" + bulkCountStr);
								
								cursor = lineEndCursor + 2;// CR + LF
							}
							
							{
								// : format version
								var lineEndCursor = ReadLine(sourceBuffer, cursor, length);
								if (lineEndCursor == -1) return new ScanResult(false);
								
								cursor = cursor + 1;// add header byte size = 1.
								
								version = new ArraySegment<byte>(sourceBuffer, cursor, lineEndCursor - cursor);
								// Disquuun.Log(":version:" + version);
								
								cursor = lineEndCursor + 2;// CR + LF
							}
							
							{
								// $ this node id
								var lineEndCursor = ReadLine(sourceBuffer, cursor, length);
								if (lineEndCursor == -1) return new ScanResult(false);
								
								cursor = cursor + 1;// add header byte size = 1.
								
								var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor - cursor);
								var strNum = Convert.ToInt32(countStr);
								// Disquuun.Log("id strNum:" + strNum);
								
								cursor = lineEndCursor + 2;// CR + LF
								
								if (ShortageOfReadableLength(sourceBuffer, cursor, strNum)) return new ScanResult(false);
								thisNodeId = new ArraySegment<byte>(sourceBuffer, cursor, strNum);
								// Disquuun.Log("thisNodeId:" + thisNodeId);
								
								cursor = cursor + strNum + 2;// CR + LF
							}
							
							{
								// * node ids
								var lineEndCursor = ReadLine(sourceBuffer, cursor, length);
								cursor = cursor + 1;// add header byte size = 1.
								
								var bulkCountStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor - cursor);
								var bulkCountNum = Convert.ToInt32(bulkCountStr);
								// Disquuun.Log("bulkCountNum:" + bulkCountNum);
								
								cursor = lineEndCursor + 2;// CR + LF
								
								// nodeId, ip, port, priority.
								for (var i = 0; i < bulkCountNum/4; i++) {
									ArraySegment<byte> idStr;
									
									// $ nodeId
									{
										var lineEndCursor2 = ReadLine(sourceBuffer, cursor, length);
										if (lineEndCursor2 == -1) return new ScanResult(false);
										cursor = cursor + 1;// add header byte size = 1.
										
										var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor2 - cursor);
										var strNum = Convert.ToInt32(countStr);
										
										cursor = lineEndCursor2 + 2;// CR + LF
										
										if (ShortageOfReadableLength(sourceBuffer, cursor, strNum)) return new ScanResult(false);
										idStr = new ArraySegment<byte>(sourceBuffer, cursor, strNum);
										nodeIdsAndInfos.Add(idStr);
										
										cursor = cursor + strNum + 2;// CR + LF
									}
									
									{
										var lineEndCursor2 = ReadLine(sourceBuffer, cursor, length);
										if (lineEndCursor2 == -1) return new ScanResult(false);
										cursor = cursor + 1;// add header byte size = 1.
										
										var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor2 - cursor);
										var strNum = Convert.ToInt32(countStr);
										
										cursor = lineEndCursor2 + 2;// CR + LF
										
										if (ShortageOfReadableLength(sourceBuffer, cursor, strNum)) return new ScanResult(false);
										var ipStr = new ArraySegment<byte>(sourceBuffer, cursor, strNum);
										nodeIdsAndInfos.Add(ipStr);
										
										cursor = cursor + strNum + 2;// CR + LF
									}
									
									{
										var lineEndCursor2 = ReadLine(sourceBuffer, cursor, length);
										if (lineEndCursor2 == -1) return new ScanResult(false);
										cursor = cursor + 1;// add header byte size = 1.
										
										var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor2 - cursor);
										var strNum = Convert.ToInt32(countStr);
										
										cursor = lineEndCursor2 + 2;// CR + LF
										
										if (ShortageOfReadableLength(sourceBuffer, cursor, strNum)) return new ScanResult(false);
										var portStr = new ArraySegment<byte>(sourceBuffer, cursor, strNum);
										nodeIdsAndInfos.Add(portStr);
										
										cursor = cursor + strNum + 2;// CR + LF
									}
									
									{
										var lineEndCursor2 = ReadLine(sourceBuffer, cursor, length);
										if (lineEndCursor2 == -1) return new ScanResult(false);
										cursor = cursor + 1;// add header byte size = 1.
										
										var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor2 - cursor);
										var strNum = Convert.ToInt32(countStr);
										
										cursor = lineEndCursor2 + 2;// CR + LF
										
										if (ShortageOfReadableLength(sourceBuffer, cursor, strNum)) return new ScanResult(false);
										var priorityStr = new ArraySegment<byte>(sourceBuffer, cursor, strNum);
										nodeIdsAndInfos.Add(priorityStr);
										
										cursor = cursor + strNum + 2;// CR + LF
									}
								}
							}
							
							
							var byteDatas = new DisquuunResult[1 + nodeIdsAndInfos.Count/4];
							byteDatas[0] = new DisquuunResult(version, thisNodeId);
							
							for (var index = 0; index < nodeIdsAndInfos.Count/4; index++) {
								var nodeId = nodeIdsAndInfos[index*4 + 0];
								var ip = nodeIdsAndInfos[index*4 + 1];
								var port = nodeIdsAndInfos[index*4 + 2];
								var priority = nodeIdsAndInfos[index*4 + 3];
								
								byteDatas[index + 1] = new DisquuunResult(nodeId, ip, port, priority);
							}
							
							return new ScanResult(cursor, true, byteDatas);
						}
					}
					break;
				}
				case DisqueCommand.QLEN: {
					switch (sourceBuffer[cursor]) {
						case ByteInt: {
							// : format version
							var lineEndCursor = ReadLine(sourceBuffer, cursor, length);
							if (lineEndCursor == -1) return new ScanResult(false);
							cursor = cursor + 1;// add header byte size = 1.
							
							var countBuffer = new ArraySegment<byte>(sourceBuffer, cursor, lineEndCursor - cursor);
							
							var byteData = new DisquuunResult(countBuffer);
							
							cursor = lineEndCursor + 2;// CR + LF
							
							return new ScanResult(cursor, true, new DisquuunResult[]{byteData});
						}
					}

					break;
				}
				case DisqueCommand.QSTAT: {
					// * count of item.
					var bulkCountNum = 0;
					{
						var lineEndCursor = ReadLine(sourceBuffer, cursor, length);
						if (lineEndCursor == -1) return new ScanResult(false);
						
						cursor = cursor + 1;// add header byte size = 1.
						
						var bulkCountStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor - cursor);
						bulkCountNum = Convert.ToInt32(bulkCountStr);
						
						cursor = lineEndCursor + 2;// CR + LF
					}
					
					// items are key & value pair(maybe "import-from" will not match..)
					var itemCount = bulkCountNum / 2;
					
					var results = new DisquuunResult[itemCount];
					for (var i = 0; i < itemCount; i++) {
						ArraySegment<byte> keyBytes;
						{// key ($)
							var lineEndCursor2 = ReadLine(sourceBuffer, cursor, length);
							if (lineEndCursor2 == -1) return new ScanResult(false);
							cursor = cursor + 1;// add header byte size = 1.
							
							var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor2 - cursor);
							var strNum = Convert.ToInt32(countStr);
							
							cursor = lineEndCursor2 + 2;// CR + LF
							
							if (ShortageOfReadableLength(sourceBuffer, cursor, strNum)) return new ScanResult(false);
							keyBytes = new ArraySegment<byte>(sourceBuffer, cursor, strNum);
							
							cursor = cursor + strNum + 2;// CR + LF
						}
												
						{// value ($ or * or :)
							ArraySegment<byte> valBytes;
							
							var type = sourceBuffer[cursor];
							/*
								check next parameter = value parameter's type.
								$ or * or : is expected.
							*/
							switch (type){
								case ByteBulk: {
									// $ have string value.
									var lineEndCursor3 = ReadLine(sourceBuffer, cursor, length);
									if (lineEndCursor3 == -1) return new ScanResult(false);
									
									cursor = cursor + 1;// add header byte size = 1.
							
									var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor3 - cursor);
									var strNum = Convert.ToInt32(countStr);
									
									cursor = lineEndCursor3 + 2;// CR + LF
									
									if (ShortageOfReadableLength(sourceBuffer, cursor, strNum)) return new ScanResult(false);
									valBytes = new ArraySegment<byte>(sourceBuffer, cursor, strNum);
									
									cursor = cursor + strNum + 2;// CR + LF
									break;	
								}
								case ByteMultiBulk:
								case ByteInt: {
									// * or : have number value.
									var lineEndCursor3 = ReadLine(sourceBuffer, cursor, length);
									if (lineEndCursor3 == -1) return new ScanResult(false);
									
									cursor = cursor + 1;// add header byte size = 1.
							
									var countStr = Encoding.UTF8.GetString(sourceBuffer, cursor, lineEndCursor3 - cursor);
									var strNum = countStr.Length;
									
									valBytes = new ArraySegment<byte>(sourceBuffer, cursor, strNum);
									
									cursor = lineEndCursor3 + 2;// CR + LF
									break;
								}
								default: {
									throw new Exception("qstat unexpected type:" + type);
								}
							}
							results[i] = new DisquuunResult(keyBytes, valBytes);
						}
					}
					return new ScanResult(cursor, true, results);
				}
				default: {
					throw new Exception("error command:" + command + " unhandled:" + sourceBuffer[cursor] + " data:" + Encoding.UTF8.GetString(sourceBuffer));
				}
			}
			return new ScanResult(false);
		}

		private static bool ShortageOfReadableLength (byte[] source, int cursor, int length) {
			if (cursor + length < source.Length) return false;
			return true;
		}

		public static int ReadLine (byte[] bytes, int cursor, long length) {
			while (cursor < length) {
				if (bytes[cursor] == ByteLF) return cursor - 1;
				cursor++;
			}
			
			// Disquuun.Log("overflow detected.");
			return -1;
		}
	}



}