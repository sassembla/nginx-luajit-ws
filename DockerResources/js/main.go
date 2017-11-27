package main

import (
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


	// ログをファイルに書き込むためのハンドラ
	f, err := os.OpenFile("test.log", os.O_RDWR|os.O_APPEND|os.O_CREATE, 0660);
		

	defer f.Close()


	// 適当な無限ループ
	for {

		// ここで、addrがグローバルなip + ポート番号になってるはず。aws上で追試したいね。


		n, addr, err := ServerConn.ReadFromUDP(buf)

		fmt.Printf("received: %s from: %s\n", string(buf[0:n]), addr)

		if err != nil {
			fmt.Println("error: ", err)
		}

		if _, err = f.WriteString(string(buf[0:n])); err != nil {
		    panic(err)
		}

		ServerConn.WriteTo(buf[0:n], addr)
	}
}
