docker rm -f locust_master locust_slave0 locust_slave1 locust_slave2 locust_slave3
# docker build -t locust-test .
# docker run -e LOCUST_MODE=slave -e MASTER_HOST=127.0.0.1 --name locust_slave0 -p 5557 -p 5558 locust-test &
# docker run -e LOCUST_MODE=slave -e MASTER_HOST=127.0.0.1 --name locust_slave1 -p 5557 -p 5558 locust-test &
# docker run -e LOCUST_MODE=slave -e MASTER_HOST=127.0.0.1 --name locust_slave2 -p 5557 -p 5558 locust-test &
docker run -e LOCUST_MODE=standalone --name locust_master -p 8089:8089  -p 5557 -p 5558 locust-test