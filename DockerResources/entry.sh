nohup /nginx-1.13.6/1.13.6/go/go-udp-server &
/nginx-1.13.6/1.13.6/sbin/nginx && /disque-master/src/disque-server --daemonize yes && cd /nginx-1.13.6/1.13.6/csharp && sh run.sh