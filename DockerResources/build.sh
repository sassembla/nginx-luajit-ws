PROJECT_PATH=$(pwd)

NGINX_VERSION=1.13.6
NGX_DEVEL_KIT="dependencies/ngx_devel_kit-0.3.0"
LUA_NGX_MOD="dependencies/lua-nginx-module-0.10.11"

export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include/luajit-2.1

# make & install nginx to PROJECT_PATH/NGINX_VERSION
./configure \
	--with-stream \
	--with-http_stub_status_module \
	--with-ld-opt="-Wl,-rpath,$LUAJIT_LIB" \
	--prefix=$PROJECT_PATH/$NGINX_VERSION \
	--add-module=$NGX_DEVEL_KIT \
	--add-module=$LUA_NGX_MOD

make -j2
make install