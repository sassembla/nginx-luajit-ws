FROM ubuntu

ENV NGINX_VERSION 1.13.6
ENV LUAJIT_VERSION 2.1.0-beta3
ENV NGINX_DEVEL_KIT_VERSION v0.3.0
ENV NGINX_LUAJIT_VERSION v0.10.11


# ready tools.
RUN apt-get update && apt-get install -y \
  gcc \
  g++ \
  make \
  zlib1g-dev \
  libpcre3-dev \
  libssl-dev\
  wget \
  unzip \
  golang

RUN apt-get update && apt-get install -y curl apt-transport-https

RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg

RUN mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg

RUN sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-xenial-prod xenial main" > /etc/apt/sources.list.d/dotnetdev.list'

RUN apt-get update && apt-get install -y dotnet-sdk-2.0.0  


# download and make disque.
RUN wget https://github.com/antirez/disque/archive/master.zip && unzip master.zip && rm master.zip && ls -l && cd disque-master/src && make


# download nginx.
RUN wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz && tar -xzvf nginx-$NGINX_VERSION.tar.gz && rm nginx-$NGINX_VERSION.tar.gz

# add luajit module.
RUN wget http://luajit.org/download/LuaJIT-$LUAJIT_VERSION.tar.gz && tar -xzvf LuaJIT-$LUAJIT_VERSION.tar.gz && rm LuaJIT-$LUAJIT_VERSION.tar.gz && cd LuaJIT-$LUAJIT_VERSION/ && make && make install

# add nginx tools, lua module and njs module.
RUN mkdir nginx-$NGINX_VERSION/dependencies && cd nginx-$NGINX_VERSION/dependencies && \
	wget https://github.com/simpl/ngx_devel_kit/archive/$NGINX_DEVEL_KIT_VERSION.zip && unzip $NGINX_DEVEL_KIT_VERSION.zip && rm $NGINX_DEVEL_KIT_VERSION.zip && \
	wget https://github.com/openresty/lua-nginx-module/archive/$NGINX_LUAJIT_VERSION.zip && unzip $NGINX_LUAJIT_VERSION.zip && rm $NGINX_LUAJIT_VERSION.zip


# add nginx build shell.
COPY ./DockerResources/build.sh nginx-$NGINX_VERSION/build.sh

# build nginx.
RUN cd nginx-$NGINX_VERSION && sh build.sh


# add go sources.
RUN mkdir nginx-$NGINX_VERSION/$NGINX_VERSION/go
COPY ./DockerResources/go nginx-$NGINX_VERSION/$NGINX_VERSION/go

# make go udp server.
RUN go build -o /nginx-$NGINX_VERSION/$NGINX_VERSION/go/go-udp-server /nginx-$NGINX_VERSION/$NGINX_VERSION/go/main.go


# overwrite nginx conf.
COPY ./DockerResources/nginx.conf nginx-$NGINX_VERSION/$NGINX_VERSION/conf/


# add c# sources.
RUN mkdir nginx-$NGINX_VERSION/$NGINX_VERSION/csharp
COPY ./DockerResources/csharp nginx-$NGINX_VERSION/$NGINX_VERSION/csharp

# make c# server.
run cd nginx-$NGINX_VERSION/$NGINX_VERSION/csharp && dotnet build


# install redis for test.
RUN curl -O http://download.redis.io/redis-stable.tar.gz && tar xzvf redis-stable.tar.gz && cd redis-stable && make


# add lua sources.
RUN mkdir nginx-$NGINX_VERSION/$NGINX_VERSION/lua
COPY ./DockerResources/lua nginx-$NGINX_VERSION/$NGINX_VERSION/lua


COPY ./DockerResources/entry.sh entry.sh

# run nginx & disque-server & go-udp-server & echo server.
ENTRYPOINT sh entry.sh
