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
udpサーバのポートを可変にしていかないといけない。できるのかな。
"""


def continue_connect():

	# Create a udp socket
	sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

	# server_ip = "172.20.10.3"
	server_ip = "150.95.177.62"

	server_port = 8080

	udp_server_addr = (server_ip, server_port)


	# 適当なbyteを担当マシンへと送付、レスポンスを受けたら、
	data = bytearray(str.encode("my udp packet."))
	sock.sendto(data, (server_ip, server_port))

	current_udp_port = sock.getsockname()[1]

	ipAndPort = ""

	while True:
		data, address = sock.recvfrom(1024)
		print('received %s bytes from %s' % (len(data), address))
		print("data:", data)
		ipAndPort = data
		break

	# 自前で閉じるとどうなるんだろ。-> ソケット自体の状態には関連してないみたい。ふむ、、
	# sock.close()


	ip = str(ipAndPort).split(':')[0][2:]
	port = str(ipAndPort).split(':')[1][0:-1]

	print("first udp received, start websocket connection. ip:", ip, " port:", port)

	path = "sample_disque_client"
	# path = "disque_clientRankerChat"

	conn = create_connection("ws://" + server_ip + ":" + str(server_port) + "/" + path, header={"ip": ip, "port": port}, subprotocols=["binary"])
	print("connect succeeded.")


	# udpとwsの両方を受信し続ける。

	executor = concurrent.futures.ThreadPoolExecutor(max_workers=2)

	ws_count = 0
	udp_count = 0

	# udp receiver.
	def udpReceive():
		try:
			while True:
				# print("start receive. sock:", sock.gettimeout())
				data, address = sock.recvfrom(1024)
				# print("udpReceive.")
				
		except Exception as e:
			print("e:", e)
		finally:
			pass

	fut = executor.submit(udpReceive)
	# fut.add_done_callback(countup)

    # send first data to server.
	result = conn.send_binary("my ws packet.")
	
	while True:
		result = conn.recv()
		
		if ws_count%100 == 0:
			print("ws_count:", ws_count)
		
		time.sleep(0.1)#10 message per sec.

		# send something.
		conn.send("testdata______________________")
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

