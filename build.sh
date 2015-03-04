projectpath=$(pwd)

# test with 2.0.3_1. we'll update it with 2.1.x 
export LUAJIT_LIB=$projectpath/luajit-2.0.3_1/2.0.3_1/lib
export LUAJIT_INC=$projectpath/luajit-2.0.3_1/2.0.3_1/include/luajit-2.0

# same folder contains below.
NGX_DEVEL_KIT="ngx_devel_kit-0.2.19"
LUA_NGX_MOD="lua-nginx-module-0.9.15"

# make & install nginx to PROJECT_PATH/bin
./configure --prefix=$projectpath/bin \
	--with-ld-opt='-Wl,-rpath,$LUAJIT_LIB' \
	--add-module=$NGX_DEVEL_KIT \
	--add-module=$LUA_NGX_MOD \
	--with-pcre=pcre-8.36

make -j2
make install