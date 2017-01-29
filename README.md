# nginx-luajit-ws

![SS](/Doc/graph.png)

nginxでluaを使ってWebSocketを受け付ける。


1. nginx上のluaでClient-ServerをWebSocket接続
2. すべての接続がmessageQueueを介して一箇所のcontextに収束
3. contextはmessageQueueにアクセスできさえすれば要件を満たせる。どんな言語でも環境でも書けるはず
4. contextとWebSocket接続が疎結合なので、接続保ったままcontextの更新が可能(単に別なだけ)


## requirement & dependency
* disque rc1 (as messageQueue)
* lua files

 
 
## installation
そのうちdockerfileとかにするつもり。
see installation.txt