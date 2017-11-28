package main

import (
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
		nginxからのproxyを受ける->nginx上のproxyで受けてしまうと、同じポートで送出できない。
		ので、nginxでのudp proxyは不要ということになるが、うーん。まあようはlistenしなければいいんだよね。

		あるいはtokenを返すのに使うか。

		proxyしてることで、このソケットからのoutが特殊なことになってくれるのでは？という期待がある。
	*/
	


	// receiver
	// ここでudpのポートが決定されてしまうのでは？感があるが、ここから返したらどうなるんだろう->proxyしてる部分に対して綺麗に返る。なるほど。
	// streamの先にはいろいろ書けるので、おおーー分散できるね。自分に到達できるキーを返せばいい、と。で、外部に見せるポートは8080唯一つになる。
	ServerAddr, err := net.ResolveUDPAddr("udp", ":8081")
	

	CheckError(err)

	// start listen.
	ServerConn, err := net.ListenUDP("udp", ServerAddr)
	
	CheckError(err)
	

	defer ServerConn.Close()


	// 受け取りバッファ
	buf := make([]byte, 1024)

	
	// 適当な無限ループ
	for {
		n, addr, err := ServerConn.ReadFromUDP(buf)

		fmt.Printf("received: %s from: %s, %d\n", string(buf[0]), addr, n)

		if err != nil {
			fmt.Println("error: ", err)
		}

		if buf[0] == 'd' {
			// ここで、特定の値が来た場合、
			continue
		}


		portStr := strconv.Itoa(addr.Port)

		// ポート番号を返す。
		ServerConn.WriteTo([]byte(portStr), addr)
	}
}
