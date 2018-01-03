package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"path/filepath"
	"strconv"
)

// CheckError checks for errors
func CheckError(err error) {
	if err != nil {
		fmt.Println("Error: ", err)
		os.Exit(0)
	}
}

func main() {

	file, err := os.OpenFile("file.txt", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		// log.Fatalln("Failed to open log file", output, ":", err)
	}

	multi := io.MultiWriter(file, os.Stdout)

	logger := log.New(multi, "go-udp-server:", log.Ldate|log.Ltime|log.Lshortfile)

	/*
		・client -> go udp server でglobal ip/portを取得
		・nginx lua -> go udp server -> client へとデータの送付
		nginx streamのproxy passを通過しているので、このサーバのIOは全てnginxの出力として現れる。
	*/
	const socketName = "go-udp-server"

	// unix domain socket base path.
	defaultDomainSocketPath := os.TempDir()
	domainSocketPath := flag.String("domain", defaultDomainSocketPath, "the base path for create unix domain socket. default is os.TempDir()")

	// port.
	defaultReceivePort := 8081
	receivePort := flag.Int("port", defaultReceivePort, "the port for receiving udp data. default is 8081.")

	flag.Parse()

	logger.Println("ready go-udp-server. domain:", *domainSocketPath, socketName, "port:", *receivePort)

	// udp receiver/sender.
	ServerAddr, err := net.ResolveUDPAddr("udp", ":"+strconv.Itoa(*receivePort))

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
				logger.Println("error:", err)
				continue
			}

			if buf2[0] == 'd' {
				logger.Println("これ機能してるの？")
				continue
			}

			addrStr := strconv.Itoa(addr.Port)

			// ポート番号を返す。
			ServerConn.WriteTo([]byte(addrStr), addr)
		}
	}()

	// start unix domain socket listening.
	// unix domain socket receiver.
	path := filepath.Join(*domainSocketPath, socketName)
	os.Remove(path)

	unixConn, err := net.ListenPacket("unixgram", path)
	CheckError(err)

	// set permission to unix domain socket file.
	err = os.Chmod(path, 0777)
	CheckError(err)

	defer unixConn.Close()

	buf := make([]byte, 1024)
	targetIP := net.ParseIP("127.0.0.1")

	for {
		n, _, err := unixConn.ReadFrom(buf)

		count, err := strconv.Atoi(string(buf[:1]))
		// logger.Println("count:", count, string(buf))

		if err != nil {
			logger.Println("error1:", err)
			continue
		}

		port := string(buf[1 : count+1])
		// logger.Println("port:", port)

		portNum, err := strconv.Atoi(port)
		if err != nil {
			logger.Println("error2:", err)
			continue
		}

		targetAddr := net.UDPAddr{IP: targetIP, Port: portNum, Zone: "sample"}

		data := buf[count+1 : n]
		// send udp data to target port.
		ServerConn.WriteTo(data, &targetAddr)
	}
}
