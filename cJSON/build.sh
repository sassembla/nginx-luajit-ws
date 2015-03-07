gcc -c cJSON.c -fPIC
gcc -shared -o cJSON.so cJSON.o -undefined dynamic_lookup -v
