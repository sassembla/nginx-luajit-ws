using System;
using System.Text;
using System.Linq;
using System.Security.Cryptography;
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;
using DisquuunCore;
using DisquuunCore.Deserialize;

namespace netcore
{
    class Program
    {
        static void Main(string[] args)
        {
        	var idLen = "09aac32820d3d25d3b787e1e7622cf090000".Length;

            var serverQueueId = "sample_disque_client_context";
        	Disquuun disquuun = null;

            disquuun = new Disquuun("127.0.0.1", 7711, 1024, 10,
				disquuunId => {
					disquuun.GetJob(new string[]{serverQueueId}).Loop(
						(command, data) => {
							var jobDatas = DisquuunDeserializer.GetJob(data);

							var jobIds = jobDatas.Select(data1 => data1.jobId).ToArray();
							var datas = jobDatas.Select(data2 => data2.jobData).ToArray();
							
							// fastack it.
							disquuun.FastAck(jobIds).Async(
								(fastAckCommand, fastAckData) => {} 
							);
							
							// reflect datas to cluent.
							foreach (var sendData in datas) {
								// Console.WriteLine("head:" + sendData[0] + " is:" + (sendData[0] == 2));//
								if (sendData[0] == '2' || sendData[0] == '3') {
									// pass.
								} else {
									// skip data.
									continue;
								}

								var targetQueueId = new byte[idLen];
								var queueData = new byte[sendData.Length - (idLen + 1)];

								Buffer.BlockCopy(sendData, 1, targetQueueId, 0, targetQueueId.Length);
								Buffer.BlockCopy(sendData, targetQueueId.Length + 1, queueData, 0, queueData.Length);

								var queueStr = Encoding.UTF8.GetString(targetQueueId);
								// Console.WriteLine("queueStr:" + queueStr);
								disquuun.Pipeline(disquuun.AddJob(queueStr, queueData));
							}
							disquuun.Pipeline().Execute((pCommand, pData) => {});
							return true;
						}
					);
				}
			);

			Console.ReadLine();
        }
    }
}

// namespace MyBenchmarks
// {
//     public class Md5VsSha256
//     {
//         private const int N = 10000;
//         private readonly byte[] data;

//         private readonly SHA256 sha256 = SHA256.Create();
//         private readonly MD5 md5 = MD5.Create();

//         public Md5VsSha256()
//         {
//             data = new byte[N];
//             new Random(42).NextBytes(data);
//         }

//         [Benchmark]
//         public byte[] Sha256() => sha256.ComputeHash(data);

//         [Benchmark]
//         public byte[] Md5() => md5.ComputeHash(data);
//     }

//     public class Program
//     {
//         public static void Main(string[] args)
//         {
//             var summary = BenchmarkRunner.Run<Md5VsSha256>();
//         }
//     }
// }
