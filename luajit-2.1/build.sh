luajit_projectpath=$(pwd)
echo $luajit_projectpath

make
make install "PREFIX=$luajit_projectpath"