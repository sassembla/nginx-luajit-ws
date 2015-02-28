# tell nginx's build system where to find LuaJIT 2.1:
export LUAJIT_LIB=/path/to/luajit/lib
export LUAJIT_INC=/path/to/luajit/include/luajit-2.1

NGX_DEVEL_KIT="ngx_devel_kit-0.2.19"
LUA_NGX_MOD="lua-nginx-module-0.9.15"

# Here we assume Nginx is to be installed under /opt/nginx/.
./configure --prefix=/opt/nginx \
	--with-ld-opt='-Wl,-rpath,$LUAJIT_LIB" \
	--add-module=$NGX_DEVEL_KIT \
	--add-module=$LUA_NGX_MOD

# make -j2
# make install