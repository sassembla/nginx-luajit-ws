FROM centos

# ready tools.
RUN yum -y install \
  gcc \
  gcc-c++ \
  make \
  zlib-devel \
  pcre-devel \
  openssl-devel \
  wget \
  unzip

# download nginx.
RUN wget 'http://nginx.org/download/nginx-1.11.9.tar.gz' && tar -xzvf nginx-1.11.9.tar.gz && rm nginx-1.11.9.tar.gz

# add luajit module.
RUN wget 'http://luajit.org/download/LuaJIT-2.1.0-beta2.tar.gz' && tar -xzvf LuaJIT-2.1.0-beta2.tar.gz && rm LuaJIT-2.1.0-beta2.tar.gz && cd LuaJIT-2.1.0-beta2/ && make && make install

# add nginx tools and lua module.
RUN mkdir nginx-1.11.9/dependencies && cd nginx-1.11.9/dependencies && wget 'https://github.com/simpl/ngx_devel_kit/archive/v0.3.0.zip' && unzip v0.3.0.zip && rm v0.3.0.zip && wget 'https://github.com/openresty/lua-nginx-module/archive/v0.10.7.zip' && unzip v0.10.7.zip && rm v0.10.7.zip

# add shell.
COPY ./build.sh nginx-1.11.9/build.sh

# build nginx.
RUN cd nginx-1.11.9 && sh build.sh

# download and make disque.
RUN wget https://github.com/antirez/disque/archive/master.zip && unzip master.zip && rm master.zip && ls -l && cd disque-master/src && make


# add lua sources.
RUN mkdir nginx-1.11.9/1.11.9/lua && ls -l
COPY ./lua nginx-1.11.9/1.11.9/lua

# overwrite nginx conf.
COPY ./nginx.conf nginx-1.11.9/1.11.9/conf/


# run nginx & disque-server.
ENTRYPOINT /nginx-1.11.9/1.11.9/sbin/nginx && /disque-master/src/disque-server
