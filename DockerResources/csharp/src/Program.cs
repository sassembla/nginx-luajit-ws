using System;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
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

            var serverQueueId = args[0];
            Disquuun disquuun = null;
            var dataDicts = new Dictionary<string, List<byte[]>>();


            var lockObj = new object();

            disquuun = new Disquuun("127.0.0.1", 7711, 1024, 30,
                disquuunId =>
                {
                    disquuun.GetJob(new string[] { serverQueueId }).Loop(
                        (command, data) =>
                        {
                            var jobDatas = DisquuunDeserializer.GetJob(data);

                            var jobIds = jobDatas.Select(data1 => data1.jobId).ToArray();
                            var datas = jobDatas.Select(data2 => data2.jobData).ToArray();

                            // fastack it.
                            disquuun.FastAck(jobIds).Async((a, b) => { });

                            // reflect datas to client.
                            foreach (var sendData in datas)
                            {
                                // Console.WriteLine("head:" + sendData[0] + " is:" + (sendData[0] == 2));//
                                if (sendData[0] == '2' || sendData[0] == '3')
                                {
                                    // pass.
                                }
                                else
                                {
                                    // skip data.
                                    continue;
                                }

                                var targetQueueId = new byte[idLen];
                                var queueData = new byte[sendData.Length - (idLen + 1)];

                                Buffer.BlockCopy(sendData, 1, targetQueueId, 0, targetQueueId.Length);
                                Buffer.BlockCopy(sendData, targetQueueId.Length + 1, queueData, 0, queueData.Length);

                                var queueStr = Encoding.UTF8.GetString(targetQueueId);

                                lock (lockObj)
                                {
                                    if (!dataDicts.ContainsKey(queueStr))
                                    {
                                        dataDicts[queueStr] = new List<byte[]>();
                                    }

                                    dataDicts[queueStr].Add(queueData);
                                }
                            }
                            return true;
                        }
                    );
                }
            );

            Task.Run(async () =>
            {
                try
                {
                    while (true)
                    {
                        lock (lockObj)
                        {
                            foreach (var dataItem in dataDicts)
                            {
                                var key = dataItem.Key;
                                var datas = dataItem.Value;

                                foreach (var data in datas)
                                {
                                    disquuun.Pipeline(disquuun.AddJob(key, data));
                                }
                            }

                            dataDicts.Clear();
                        }

                        disquuun.Pipeline().Execute((pCommand, pData) => { });

                        await Task.Delay(16);
                    }
                }
                catch (Exception e)
                {
                    Console.WriteLine("dead by error, e:" + e);
                }
                Console.WriteLine("finish to run.");
            });

            Console.ReadLine();
        }
    }
}