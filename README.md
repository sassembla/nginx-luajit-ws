# nginx-luajit-ws

![SS](/Doc/graph.png)

nginxでluaを使ってWebSocketを受け付ける。


1. nginx上のluaでClient-ServerをWebSocket接続
2. すべての接続がmessageQueueを介して一箇所のcontextに収束
3. contextはmessageQueueにアクセスできさえすれば要件を満たせる。どんな言語でも環境でも書けるはず
4. contextとWebSocket接続が疎結合なので、接続保ったままcontextの更新が可能(単に別なだけ)


# Build image

```shellscript
docker build -f ubuntu.dockerfile -t nginx-luajit-ubuntu .
```

# Create container from image

```shellscript
docker run -ti -d --name nginx_luajit -p 8080:80 -v $(pwd)/logs:/nginx-1.11.9/1.11.9/logs nginx-luajit-ubuntu
```

# Connect to connnection server

open client.html by web browser.


# Logs

all nginx logs are located in ./logs folder.