PROJECT_PATH=$(pwd)

NGINX_VERSION=1.13.6
NGX_DEVEL_KIT="dependencies/ngx_devel_kit-0.3.0"
LUA_NGX_MOD="dependencies/lua-nginx-module-0.10.11"
# LUA_NJS_MOD="dependencies/njs-0.1.14/nginx"

export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include/luajit-2.1

# make & install nginx to PROJECT_PATH/NGINX_VERSION
./configure \
	--with-stream \
	--with-ld-opt="-Wl,-rpath,$LUAJIT_LIB" \
	--prefix=$PROJECT_PATH/$NGINX_VERSION \
	--add-module=$NGX_DEVEL_KIT \
	--add-module=$LUA_NGX_MOD
	# --add-module=$LUA_NJS_MOD


make -j2
make install