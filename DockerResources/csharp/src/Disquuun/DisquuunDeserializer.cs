using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace DisquuunCore.Deserialize {
	
	public static class DisquuunDeserializer {
		public static byte[] ByteArrayFromSegment (ArraySegment<byte> arraySegment) {
			var buffer = new byte[arraySegment.Count];
			Buffer.BlockCopy(arraySegment.Array, arraySegment.Offset, buffer, 0, arraySegment.Count);
			return buffer;
		}

		
		public static string AddJob (DisquuunResult[] data) {
			var idStrBytes = ByteArrayFromSegment(data[0].bytesArray[0]);
			return Encoding.UTF8.GetString(idStrBytes);
		}
		
		public struct JobData {
			public readonly string jobId;
			public readonly byte[] jobData;
			
			public readonly int nackCount;
			public readonly int additionalDeliveriesCount;
			
			public JobData (DisquuunResult dataSourceBytes) {
				this.jobId = Encoding.UTF8.GetString(ByteArrayFromSegment(dataSourceBytes.bytesArray[0]));
				this.jobData = ByteArrayFromSegment(dataSourceBytes.bytesArray[1]);
				
				if (dataSourceBytes.bytesArray.Length < 3) {
					nackCount = -1;
					additionalDeliveriesCount = -1;
				} else {// with "withcounters" option
					nackCount = Convert.ToInt32(Encoding.UTF8.GetString(ByteArrayFromSegment(dataSourceBytes.bytesArray[2])));
					additionalDeliveriesCount = Convert.ToInt32(Encoding.UTF8.GetString(ByteArrayFromSegment(dataSourceBytes.bytesArray[3])));
				}
			}
		}
		
		public static JobData[] GetJob (DisquuunResult[] data) {
			var jobDatas = new JobData[data.Length];
			for (var i = 0; i < data.Length; i++) {
				var jobDataSource = data[i];
				jobDatas[i] = new JobData(jobDataSource);
			}
			return jobDatas;
		}
	
		public static int DeserializeInt (DisquuunResult[] data) {
			var valStr = Encoding.UTF8.GetString(ByteArrayFromSegment(data[0].bytesArray[0]));
			return Convert.ToInt32(valStr);
		}
		public static int AckJob (DisquuunResult[] data) {
			return DeserializeInt(data);
		}
		public static int FastAck (DisquuunResult[] data) {
			return DeserializeInt(data);
		}
		public static int Working (DisquuunResult[] data) {
			return DeserializeInt(data);
		}
		
		public static int Nack (DisquuunResult[] data) {
			return DeserializeInt(data);
		}
		
		
		
		public class InfoStruct {
			public struct HeaderAndValue {
				public readonly string header;
				public readonly string val;
				public HeaderAndValue (string line) {
					this.header = line.Split(':')[0];
					this.val = line.Split(':')[1];
				}
			}
			
			public readonly string rawString;
			public Server server;
			public Clients clients;
			public Memory memory;
			public Jobs jobs;
			public Queues queues;
			public Persistence persistence;
			public Stats stats;
			public CPU cpu;
			
			public InfoStruct (byte[] sourceData) {
				this.rawString = Encoding.UTF8.GetString(sourceData);
				var lisesSoucrce = rawString.Replace("\r", string.Empty);
				
				var lines = lisesSoucrce.Split('\n');
				var lineIndexies = new List<int>{0};// first index is 0.
				
				for (var i = 0; i < lines.Length; i++) {
					var line = lines[i];
					if (string.IsNullOrEmpty(line)) lineIndexies.Add(i+1);
				}
				
				for (var i = 0; i < lineIndexies.Count; i++) {
					var firstLineIndex = lineIndexies[i];
					
					var nextBlockIndex = -1;
					if (i+1 < lineIndexies.Count) nextBlockIndex = lineIndexies[i+1];
					else continue;
					
					var infoCategolyStr = lines[firstLineIndex];
					var blockHeaderAndValue = lines
												.Where((p, index) => firstLineIndex < index && index < nextBlockIndex)
												.Where(line => line.Contains(":"))
												.Select(line => new HeaderAndValue(line))
												.ToArray();
											
					switch (infoCategolyStr) {
						case "# Server": {
							this.server = new Server(blockHeaderAndValue);
							break;
						}
						case "# Clients": {
							this.clients = new Clients(blockHeaderAndValue);
							break;
						}
						case "# Memory": {
							this.memory = new Memory(blockHeaderAndValue);
							break;
						}
						case "# Jobs": {
							this.jobs = new Jobs(blockHeaderAndValue);
							break;
						}
						case "# Queues": {
							this.queues = new Queues(blockHeaderAndValue);
							break;
						}
						case "# Persistence": {
							this.persistence = new Persistence(blockHeaderAndValue);
							break;
						}
						case "# Stats": {
							this.stats = new Stats(blockHeaderAndValue);
							break;
						}
						case "# CPU": {
							this.cpu = new CPU(blockHeaderAndValue);
							break;
						}
						default: {
							// unexpected info categoly.
							break;
						}
					} 
				}
			}
			
			public class Server {
				public readonly string disque_version;//:1.0-rc1
				public readonly string disque_git_sha1;//:c95e6dc0
				public readonly string disque_git_dirty;//:1
				public readonly string disque_build_id;//:e95116bc5ef677ba
				public readonly string os;//:Darwin 15.4.0 x86_64
				public readonly string arch_bits;//:64
				public readonly string multiplexing_api;//:kqueue
				public readonly string gcc_version;//:4.2.1
				public readonly string process_id;//:11899
				public readonly string run_id;//:b184f132a28d37c7967bfa4d8ab990953b8610f2
				public readonly int 	tcp_port;//:7711
				public readonly string uptime_in_seconds;//:516
				public readonly string uptime_in_days;//:0
				public readonly string hz;//:10
				public readonly string executable;//:/Users/tartetatin/Desktop/RolePlayingChat/Server/./disque/src/disque-server
				public readonly string config_file;//:
				public Server (HeaderAndValue[] sourceDatas) {
					foreach (var sourceData in sourceDatas) {
						switch (sourceData.header) {
							case "disque_version": {
								this.disque_version = sourceData.val;
								break;
							}
							case "disque_git_sha1": {
								this.disque_git_sha1 = sourceData.val;
								break;
							}
							case "disque_git_dirty": {
								this.disque_git_dirty = sourceData.val;
								break;
							}
							case "disque_build_id": {
								this.disque_build_id = sourceData.val;
								break;
							}
							case "os": {
								this.os = sourceData.val;
								break;
							}
							case "arch_bits": {
								this.arch_bits = sourceData.val;
								break;
							}
							case "multiplexing_api": {
								this.multiplexing_api = sourceData.val;
								break;
							}
							case "gcc_version": {
								this.gcc_version = sourceData.val;
								break;
							}
							case "process_id": {
								this.process_id = sourceData.val;
								break;
							}
							case "run_id": {
								this.run_id = sourceData.val;
								break;
							}
							case "tcp_port": {
								this.tcp_port = Convert.ToInt32(sourceData.val);
								break;
							}
							case "uptime_in_seconds": {
								this.uptime_in_seconds = sourceData.val;
								break;
							}
							case "uptime_in_days": {
								this.uptime_in_days = sourceData.val;
								break;
							}
							case "hz": {
								this.hz = sourceData.val;
								break;
							}
							case "executable": {
								this.executable = sourceData.val;
								break;
							}
							case "config_file": {
								this.config_file = sourceData.val;
								break;
							}
							default: {
								break;
							}
						}
					}
					
				}
			}

			public class Clients {
				public readonly string connected_clients;//:4
				public readonly string client_longest_output_list;//:0
				public readonly string client_biggest_input_buf;//:1016
				public readonly string blocked_clients;//:1
				public Clients (HeaderAndValue[] sourceDatas) {
					foreach (var sourceData in sourceDatas) {
						switch (sourceData.header) {
							case "connected_clients": {
								this.connected_clients = sourceData.val;
								break;
							}
							case "client_longest_output_list": {
								this.client_longest_output_list = sourceData.val;
								break;
							}
							case "client_biggest_input_buf": {
								this.client_biggest_input_buf = sourceData.val;
								break;
							}
							case "blocked_clients": {
								this.blocked_clients = sourceData.val;
								break;
							}
						}
					}
				}
			}
			
			public class Memory {
				public readonly string used_memory;//:1070080
				public readonly string used_memory_human;//:1.02M
				public readonly string used_memory_rss;//:4984832
				public readonly string used_memory_peak;//:1758176
				public readonly string used_memory_peak_human;//:1.68M
				public readonly string mem_fragmentation_ratio;//:4.66
				public readonly string mem_allocator;//:libc
				public Memory (HeaderAndValue[] sourceDatas) {
					foreach (var sourceData in sourceDatas) {
						switch (sourceData.header) {
							case "used_memory": {
								this.used_memory = sourceData.val;
								break;
							}
							case "used_memory_human": {
								this.used_memory_human = sourceData.val;
								break;
							}
							case "used_memory_rss": {
								this.used_memory_rss = sourceData.val;
								break;
							}
							case "used_memory_peak": {
								this.used_memory_peak = sourceData.val;
								break;
							}
							case "used_memory_peak_human": {
								this.used_memory_peak_human = sourceData.val;
								break;
							}
							case "mem_fragmentation_ratio": {
								this.mem_fragmentation_ratio = sourceData.val;
								break;
							}
							case "mem_allocator": {
								this.mem_allocator = sourceData.val;
								break;
							}
						}
					}
				}
			}
			
			public class Jobs {
				public readonly int registered_jobs;//101
				public Jobs (HeaderAndValue[] sourceDatas) {
					foreach (var sourceData in sourceDatas) {
						switch (sourceData.header) {
							case "registered_jobs": {
								this.registered_jobs = Convert.ToInt32(sourceData.val);
								break;
							}
						}
					}
				}
			}
			
			public class Queues {
				public readonly int registered_queues;//:31
				public Queues (HeaderAndValue[] sourceDatas) {
					foreach (var sourceData in sourceDatas) {
						switch (sourceData.header) {
							case "registered_queues": {
								this.registered_queues = Convert.ToInt32(sourceData.val);
								break;
							}
						}
					}
				}
			}

			public class Persistence {
				public readonly string loading;//:0
				public readonly string aof_enabled;//:0
				public readonly string aof_state;//:off
				public readonly string aof_rewrite_in_progress;//:0
				public readonly string aof_rewrite_scheduled;//:0
				public readonly string aof_last_rewrite_time_sec;//:-1
				public readonly string aof_current_rewrite_time_sec;//:-1
				public readonly string aof_last_bgrewrite_status;//:ok
				public readonly string aof_last_write_status;//:ok
				public Persistence (HeaderAndValue[] sourceDatas) {
					foreach (var sourceData in sourceDatas) {
						switch (sourceData.header) {
							case "loading": {
								this.loading = sourceData.val;
								break;
							}
							case "aof_enabled": {
								this.aof_enabled = sourceData.val;
								break;
							}
							case "aof_state": {
								this.aof_state = sourceData.val;
								break;
							}
							case "aof_rewrite_in_progress": {
								this.aof_rewrite_in_progress = sourceData.val;
								break;
							}
							case "aof_rewrite_scheduled": {
								this.aof_rewrite_scheduled = sourceData.val;
								break;
							}
							case "aof_last_rewrite_time_sec": {
								this.aof_last_rewrite_time_sec = sourceData.val;
								break;
							}
							case "aof_current_rewrite_time_sec": {
								this.aof_current_rewrite_time_sec = sourceData.val;
								break;
							}
							case "aof_last_bgrewrite_status": {
								this.aof_last_bgrewrite_status = sourceData.val;
								break;
							}
							case "aof_last_write_status": {
								this.aof_last_write_status = sourceData.val;
								break;
							}
						}
					}
				}
			}

			public class Stats {
				public readonly string total_connections_received;//:262
				public readonly string total_commands_processed;//:856
				public readonly string instantaneous_ops_per_sec;//:55
				public readonly string total_net_input_bytes;//:2402606
				public readonly string total_net_output_bytes;//:1065901
				public readonly string instantaneous_input_kbps;//:4.07
				public readonly string instantaneous_output_kbps;//:73.92
				public readonly string rejected_connections;//:0
				public readonly string latest_fork_usec;//:0

				public Stats (HeaderAndValue[] sourceDatas) {
					foreach (var sourceData in sourceDatas) {
						switch (sourceData.header) {
							case "total_connections_received": {
								this.total_connections_received = sourceData.val;
								break;
							}
							case "total_commands_processed": {
								this.total_commands_processed = sourceData.val;
								break;
							}
							case "instantaneous_ops_per_sec": {
								this.instantaneous_ops_per_sec = sourceData.val;
								break;
							}
							case "total_net_input_bytes": {
								this.total_net_input_bytes = sourceData.val;
								break;
							}
							case "total_net_output_bytes": {
								this.total_net_output_bytes = sourceData.val;
								break;
							}
							case "instantaneous_input_kbps": {
								this.instantaneous_input_kbps = sourceData.val;
								break;
							}
							case "instantaneous_output_kbps": {
								this.instantaneous_output_kbps = sourceData.val;
								break;
							}
							case "rejected_connections": {
								this.rejected_connections = sourceData.val;
								break;
							}
							case "latest_fork_usec": {
								this.latest_fork_usec = sourceData.val;
								break;
							}
						}

					}
				}
			}

			public class CPU {
				public readonly string used_cpu_sys;//:4.47
				public readonly string used_cpu_user;//:2.96
				public readonly string used_cpu_sys_children;//:0.00
				public readonly string used_cpu_user_children;//:0.00
				public CPU (HeaderAndValue[] sourceDatas) {
					foreach (var sourceData in sourceDatas) {
						switch (sourceData.header) {
							case "used_cpu_sys": {
								this.used_cpu_sys = sourceData.val;
								break;
							}
							case "used_cpu_user": {
								this.used_cpu_user = sourceData.val;
								break;
							}
							case "used_cpu_sys_children": {
								this.used_cpu_sys_children = sourceData.val;
								break;
							}
							case "used_cpu_user_children": {
								this.used_cpu_user_children = sourceData.val;
								break;
							}
						}
					}
				}
			}
		}
		
		
		public static InfoStruct Info (DisquuunResult[] data) {
			return new InfoStruct(ByteArrayFromSegment(data[0].bytesArray[0]));
		}
		
		public struct HelloData {
			public readonly string version;
			public readonly string sourceNodeId;
			public readonly NodeData[] nodeDatas;
			public HelloData (string version, string sourceNodeId, NodeData[] nodeDatas) {
				this.version = version;
				this.sourceNodeId = sourceNodeId;
				this.nodeDatas = nodeDatas;
			}
		}
		public struct NodeData {
			public readonly string nodeId;
			public readonly string ip;
			public readonly int port;
			public readonly int priority;
			public NodeData (string nodeId, string ip, int port, int priority) {
				this.nodeId = nodeId;
				this.ip = ip;
				this.port = port;
				this.priority = priority;
			}
		}
		
		public static HelloData Hello (DisquuunResult[] data) {
			var version = Encoding.UTF8.GetString(ByteArrayFromSegment(data[0].bytesArray[0]));
			var sourceNodeId = Encoding.UTF8.GetString(ByteArrayFromSegment(data[0].bytesArray[1]));
			var nodeDatas = new List<NodeData>();
			for (var i = 1; i < data.Length; i++) {
				var nodeIdStr = Encoding.UTF8.GetString(ByteArrayFromSegment(data[i].bytesArray[0]));
				var ipStr = Encoding.UTF8.GetString(ByteArrayFromSegment(data[i].bytesArray[1]));
				var portInt = Convert.ToInt16(Encoding.UTF8.GetString(ByteArrayFromSegment(data[i].bytesArray[2])));
				var priorityInt = Convert.ToInt16(Encoding.UTF8.GetString(ByteArrayFromSegment(data[i].bytesArray[3])));
				nodeDatas.Add(new NodeData(nodeIdStr, ipStr, portInt, priorityInt));
			}
			var helloData = new HelloData(version, sourceNodeId, nodeDatas.ToArray());
			return helloData;
		}
		
		public static int Qlen (DisquuunResult[] data) {
			var qLenStr = Encoding.UTF8.GetString(ByteArrayFromSegment(data[0].bytesArray[0]));
			return Convert.ToInt32(qLenStr);
		}
		
		public class QstatData {
			public readonly string name;
			public readonly int len;	
			public readonly int age;
			public readonly int idle;
			public readonly int blocked;
			public readonly int import_from;
			public readonly int import_rate;
			public readonly int jobs_in;
			public readonly int jobs_out;
			public readonly string pause;
			
			public QstatData (DisquuunResult[] data) {
				foreach (var keyValue in data) {
					var key = Encoding.UTF8.GetString(ByteArrayFromSegment(keyValue.bytesArray[0]));
					var strVal = Encoding.UTF8.GetString(ByteArrayFromSegment(keyValue.bytesArray[1]));
					switch (key) {
						case "name": {
							this.name = strVal;
							break;
						}
						case "len": {
							this.len = Convert.ToInt32(strVal);
							break;
						}
						case "age": {
							this.age = Convert.ToInt32(strVal);
							break;
						}
						case "idle": {
							this.idle = Convert.ToInt32(strVal);
							break;
						}
						case "blocked": {
							this.blocked = Convert.ToInt32(strVal);
							break;
						}
						case "import_from": {
							this.import_from = Convert.ToInt32(strVal);
							break;
						}
						case "import_rate": {
							this.import_rate = Convert.ToInt32(strVal);
							break;
						}
						case "jobs_in": {
							this.jobs_in = Convert.ToInt32(strVal);
							break;
						}
						case "jobs_out": {
							this.jobs_out = Convert.ToInt32(strVal);
							break;
						}
						case "pause": {
							this.pause = strVal;
							break;
						}
					}
				}
			}
		}
		
		public static QstatData Qstat (DisquuunResult[] data) {
			return new QstatData(data);
		}
		
// QPEEK,// <queue-name> <count>
// ENQUEUE,// <job-id> ... <job-id>
// DEQUEUE,// <job-id> ... <job-id>
// DELJOB,// <job-id> ... <job-id>
// SHOW,// <job-id>
// QSCAN,// [COUNT <count>] [BUSYLOOP] [MINLEN <len>] [MAXLEN <len>] [IMPORTRATE <rate>]
// JSCAN,// [<cursor>] [COUNT <count>] [BUSYLOOP] [QUEUE <queue>] [STATE <state1> STATE <state2> ... STATE <stateN>] [REPLY all|id]
// PAUSE,// <queue-name> option1 [option2 ... optionN]
	
		
	}
		
		
}