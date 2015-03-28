# basically these settings are for Mac OS X.

PROJECT_PATH=$(pwd)

NGINX_VERSION=1.7.10

# build luajit 2.1 first
LUAJIT_FOLDER="luajit-2.1"
cd $LUAJIT_FOLDER
sh build.sh
cd ../

#install dylib to nginx/lib
cp $LUAJIT_FOLDER/lib/libluajit-5.1.2.1.0.dylib $NGINX_VERSION/lib


# luajit required from Lua-nginx module. set export.
export LUAJIT_LIB=$PROJECT_PATH/$LUAJIT_FOLDER/lib
export LUAJIT_INC=$PROJECT_PATH/$LUAJIT_FOLDER/include/luajit-2.1

# same folder contains below.
NGX_DEVEL_KIT="ngx_devel_kit-0.2.19"
LUA_NGX_MOD="lua-nginx-module-0.9.15"
HTTP_REDIS_MOD="ngx_http_redis-0.3.7"
ZLIB="zlib"
PCRE="pcre-8.36"

# 実行時にlibluajitを特定の位置から呼んでほしいんだが、コンパイル時に下記を指定しても実行時の読み込み箇所が変わらない(usr/local/libを探す)ので、困っている。
# --with-ld-opt="-rpath,$LUAJIT_LIB" \
# →調べてみたら、nginx-lua-moduleがconfigでその辺やってるっぽい。

# make & install nginx to PROJECT_PATH/NGINX_VERSION
./configure \
	--prefix=$PROJECT_PATH/$NGINX_VERSION \
	--add-module=$NGX_DEVEL_KIT \
	--add-module=$LUA_NGX_MOD \
	--add-module=$HTTP_REDIS_MOD \
	--with-zlib=$ZLIB \
	--with-pcre=$PCRE

make -j2
make install

otool -L $NGINX_VERSION/sbin/nginx

# for Mac. use local luajit dylib. rewrite link.
install_name_tool -change /usr/local/lib/libluajit-5.1.2.dylib $PROJECT_PATH/$NGINX_VERSION/lib/libluajit-5.1.2.1.0.dylib $NGINX_VERSION/sbin/nginx

