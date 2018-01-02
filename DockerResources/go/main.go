package main

import (
	"path/filepath"
	"strconv"
	"fmt"
	"net"
	"os"
)

// CheckError checks for errors
func CheckError(err error) {
	if err != nil {
		fmt.Println("Error: ", err)
		os.Exit(0)
	}
}

func main() {
	/*
		次のことが実現できた。
		・client -> go udp server でglobal ip/portを取得
		・nginx lua -> go udp server -> client へとデータの送付
		nginx streamのproxy passを通過しているので、このサーバのIOは全てnginxの出力として現れる。
	*/

	// udp receiver/sender.
	ServerAddr, err := net.ResolveUDPAddr("udp", ":8081")

	CheckError(err)

	// start listen.
	ServerConn, err := net.ListenUDP("udp", ServerAddr)

	CheckError(err)

	defer ServerConn.Close()

	go func() {
		// 受け取りバッファ
		buf2 := make([]byte, 1024)

		for {
			_, addr, err := ServerConn.ReadFromUDP(buf2)
			// fmt.Println("addr:", addr)

			if err != nil {
				fmt.Println("error: ", err)
				continue
			}

			if buf2[0] == 'd' {
				continue;
			}

			addrStr := strconv.Itoa(addr.Port)

			// ポート番号を返す。
			ServerConn.WriteTo([]byte(addrStr), addr)
		}
	}()

	// start unix domain socket listening.
	// unix domain socket receiver.
	path := filepath.Join(os.TempDir(), "go-udp-server")
	os.Remove(path)

	fmt.Println("unix domain path:", path)

	unixConn, err := net.ListenPacket("unixgram", path)
	CheckError(err)

	// set permission to unix domain socket file.
	err = os.Chmod(path, 0777)
	CheckError(err)

	defer unixConn.Close()

	buf := make([]byte, 1024)
	targetIp := net.ParseIP("127.0.0.1")

	for {
		n, _, err := unixConn.ReadFrom(buf)

		count, err := strconv.Atoi(string(buf[:1]))

		if err != nil {
			fmt.Println("error1: ", err)
			continue
		}

		//fmt.Println("count:", count)

		port := string(buf[1:count])// get port.
		//fmt.Println("port:", port)
		portNum, err := strconv.Atoi(port)
		if err != nil {
			fmt.Println("error2: ", err)
			continue
		}

		targetAddr := net.UDPAddr{IP:targetIp, Port:portNum, Zone:"sample"}

		data := buf[count:n]
		// send udp data to target ip:port.
		ServerConn.WriteTo(data, &targetAddr)
	}
}


