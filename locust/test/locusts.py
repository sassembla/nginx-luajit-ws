# -*- coding: utf-8 -*-
from locust import Locust, TaskSet, task
from websocket import create_connection
import time
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


def continue_connect():

	# Create a udp socket
	sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

	server_ip = "150.95.180.35"
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
		# print('received %s bytes from %s' % (len(data), address))
		# print("data:", data)
		port = data.decode("utf-8")
		break

	# 自前で閉じるとどうなるんだろ。-> ソケット自体の状態には関連してないみたい。ふむ、、
	# sock.close()

	# print("first udp received, start websocket connection. port:", port)

	path = "sample_disque_client"
	# path = "disque_clientRankerChat"

	conn = create_connection("ws://" + server_ip + ":" + str(server_port) + "/" + path, header={"token":"dummy", "param": port}, subprotocols=["binary"])
	# print("connect succeeded.")

	# udpとwsの両方を受信し続ける。

	executor = concurrent.futures.ThreadPoolExecutor(max_workers=2)

	ws_count = 0
	udp_count = 0


	# udp receiver.
	def udpReceive():
		while True:
			# print("start receive. sock:", sock.gettimeout())
			data, address = sock.recvfrom(1024)
			# countup()
			# print("udpReceive.")
			
	
	fut = executor.submit(udpReceive)
	# fut.add_done_callback(countup)

    # send first data to server.
	result = conn.send_binary("my ws packet.")
	
	while True:
		result = conn.recv()
		
		time.sleep(message_per_sec)

		# send something.
		conn.send("testdata______________________")

		# print("udp_count:", udp_count)
		ws_count = ws_count + 1


# continue_connect()


class MyTaskSet(TaskSet):
    @task
    def my_task(self):
        continue_connect()

class MyLocust(Locust):
    task_set = MyTaskSet
    min_wait = 5000
    max_wait = 15000

