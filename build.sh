# tell nginx's build system where to find LuaJIT 2.1:
# ふーむlibってどこよ、、、2.1でlibつくる方法が知りたい。

# 今回はまずやりたいことができるかどうかのチェックのために、luajit2.0.xをbrewで入れて動かす。
export LUAJIT_LIB=/usr/local/Cellar/luajit/2.0.3_1/lib
export LUAJIT_INC=/usr/local/Cellar/luajit/2.0.3_1/include/luajit-2.0

NGX_DEVEL_KIT="ngx_devel_kit-0.2.19"
LUA_NGX_MOD="lua-nginx-module-0.9.15"

# Here we assume Nginx is to be installed under /opt/nginx/.
./configure --prefix=/Users/illusionismine/Desktop/nginx-luajit/b \
	--with-ld-opt='-Wl,-rpath,$LUAJIT_LIB' \
	--add-module=$NGX_DEVEL_KIT \
	--add-module=$LUA_NGX_MOD

make -j2
make install