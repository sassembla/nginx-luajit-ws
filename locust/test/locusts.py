# -*- coding: utf-8 -*-
from locust import Locust, TaskSet, task
from websocket import create_connection
import time
import uuid
import socket
import concurrent.futures
import sys

"""
シナリオ：
udp接続、パラメータ受け取り、ws接続、ws送信、というのを一発で行う。テストケースからはこの関数一発が呼べればいい。

接続後、次のチェックがしたい。
・接続が切れたらエラーを出す
・通信が途切れたらエラーを出す
・接続に失敗したらエラーを出す
"""

udpCount = {}
tcpCount = {}

def continue_connect(connection_id):

    # Create a udp socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    server_ip = "150.95.211.59"
    # server_ip = "127.0.0.1"

    server_port = 8080
    message_per_sec = 100.0 / 1000.0
    server_path = "sample_disque_client"

    udp_server_addr = (server_ip, server_port)

    data = bytearray(str.encode("my udp packet."))
    sock.sendto(data, (server_ip, server_port))

    current_udp_port = sock.getsockname()[1]

    port = ""

    while True:
        data, address = sock.recvfrom(1024)
        port = data.decode("utf-8")
        break

    path = "sample_disque_client"

    conn = create_connection("ws://" + server_ip + ":" + str(server_port) + "/" + path, header={"token":connection_id, "param": port}, subprotocols=["binary"])
    conn.settimeout(60)
    

    # udpとwsの両方を受信し続ける。

    executor = concurrent.futures.ThreadPoolExecutor(max_workers=2)


    # udp receiver.
    def udpReceive():
        global udpCount
        udpCount[connection_id] = 0
        while True:
            data, address = sock.recvfrom(1024)
            udpCount[connection_id] = udpCount[connection_id] + 1
            
    
    executor.submit(udpReceive)

    # send first data to server.
    result = conn.send_binary(connection_id)
    uuidLen = len(connection_id)

    def tcpReceive():
        global tcpCount
        tcpCount[connection_id] = 0

        # 受診時間の間を計測、1秒待っても何もこない場合、エラーで終了
        while True:
            try:
                result = conn.recv()
                if len(result) != uuidLen:
                    print("less data received, uuid:" + str(connection_id) + " length:" + str(len(result)) + " t:" + str(tcpCount[connection_id]) + " u:" + str(udpCount[connection_id]))
                    conn.shutdown()
                    break

            except Exception as e:
                print("connection closed, uuid:" + str(connection_id) + "reason:" + str(e) + " t:" + str(tcpCount[connection_id]) + " u:" + str(udpCount[connection_id]))
                break

            tcpCount[connection_id] = tcpCount[connection_id] + 1
            time.sleep(message_per_sec)

            # send some data. 36btye.
            conn.send(connection_id)

    executor.submit(tcpReceive)
    return conn

# 単体実行を行う場合、ここで実行して待つ。
# continue_connect()


class MyTaskSet(TaskSet):
    
    def on_start(self):
        # ここで接続を行い、taskで順当にreceivedが増えているかのチェックを行う。
        self.connection_id = str(uuid.uuid4())
        conn = continue_connect(self.connection_id)
        print("established connection_id:" + self.connection_id)
        self.old = -1
        self.conn = conn
        self.dead = False
        self.stopCount = 0

    @task
    def my_task(self):
        if self.dead:
            return

        if not self.conn.is_connected():
            print("connection_id:" + self.connection_id + " is dead.")
            self.dead = True
            return

        if (tcpCount[self.connection_id] <= self.old):
            print("connection_id:" + self.connection_id + " is stopped. stop count:" + str(self.stopCount))
            self.stopCount = self.stopCount + 1

        self.old = tcpCount[self.connection_id]

class MyLocust(Locust):
    task_set = MyTaskSet
    min_wait = 1000
    max_wait = 1000

