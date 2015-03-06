projectpath=$(pwd)

# luajit requires from Lua-nginx module
export LUAJIT_LIB=$projectpath/luajit-2.1/lib
export LUAJIT_INC=$projectpath/luajit-2.1/include/luajit-2.1

# same folder contains below.
NGX_DEVEL_KIT="ngx_devel_kit-0.2.19"
LUA_NGX_MOD="lua-nginx-module-0.9.15"
HTTP_REDIS_MOD="ngx_http_redis-0.3.7"
PCRE="pcre-8.36"

# still depends on lua 5.1 dylib, we should complete it.

# make & install nginx to PROJECT_PATH/bin
./configure --prefix=$projectpath/bin \
	--with-ld-opt='-Wl,-rpath,$LUAJIT_LIB' \
	--add-module=$NGX_DEVEL_KIT \
	--add-module=$LUA_NGX_MOD \
	--add-module=$HTTP_REDIS_MOD \
	--with-pcre=$PCRE

make -j2
make install