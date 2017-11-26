docker rm -f nginx_luajit
docker build -f ubuntu.dockerfile -t nginx-luajit-ubuntu .
docker run -ti -d --name nginx_luajit -p 8080:8080 -p 8080:8080/udp -v $(pwd)/logs:/nginx-1.13.6/1.13.6/logs nginx-luajit-ubuntu