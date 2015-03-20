PROJECT_PATH=$(pwd)

# build luajit 2.1 first
LUAJIT_FOLDER="luajit-2.1"
cd $LUAJIT_FOLDER
sh build.sh
cd ../

# luajit required from Lua-nginx module. set export.
export LUAJIT_LIB=$PROJECT_PATH/$LUAJIT_FOLDER/lib
export LUAJIT_INC=$PROJECT_PATH/$LUAJIT_FOLDER/include/luajit-2.1

# same folder contains below.
NGX_DEVEL_KIT="ngx_devel_kit-0.2.19"
LUA_NGX_MOD="lua-nginx-module-0.9.15"
HTTP_REDIS_MOD="ngx_http_redis-0.3.7"
PCRE="pcre-8.36"

# make & install nginx to PROJECT_PATH/bin
./configure --prefix=$PROJECT_PATH/bin \
	--with-ld-opt='-Wl,-rpath,$LUAJIT_LIB' \
	--add-module=$NGX_DEVEL_KIT \
	--add-module=$LUA_NGX_MOD \
	--add-module=$HTTP_REDIS_MOD \
	--with-pcre=$PCRE

make -j2
make install

# use local luajit dylib.
install_name_tool -change /usr/local/lib/libluajit-5.1.2.dylib $PROJECT_PATH/bin/lib/libluajit-5.1.2.1.0.dylib bin/sbin/nginx