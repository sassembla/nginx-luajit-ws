docker rm -f locust
docker build -t locust-test .
docker run -e LOCUST_MODE=standalone --name locust -p 8089:8089 locust-test