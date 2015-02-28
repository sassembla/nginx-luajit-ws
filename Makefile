
default:	build

clean:
	rm -rf Makefile objs

build:
	$(MAKE) -f objs/Makefile
	$(MAKE) -f objs/Makefile manpage

install:
	$(MAKE) -f objs/Makefile install

upgrade:
	/Users/illusionismine/Desktop/nginx-luajit/b/sbin/nginx -t

	kill -USR2 `cat /Users/illusionismine/Desktop/nginx-luajit/b/logs/nginx.pid`
	sleep 1
	test -f /Users/illusionismine/Desktop/nginx-luajit/b/logs/nginx.pid.oldbin

	kill -QUIT `cat /Users/illusionismine/Desktop/nginx-luajit/b/logs/nginx.pid.oldbin`
