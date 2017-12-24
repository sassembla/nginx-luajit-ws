FROM ubuntu:16.04

# RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential libncursesw5-dev libreadline-dev libssl-dev libgdbm-dev libc6-dev libsqlite3-dev libxml2-dev libxslt-dev python python-dev python-setuptools && apt-get clean

RUN apt-get update
RUN apt-get install -y python3 python3-pip

RUN pip3 install websocket-client locustio

ADD run.sh /usr/local/bin/run.sh
RUN chmod 755 /usr/local/bin/run.sh

EXPOSE 8089 5557 5558

ADD ./test /test
ENV SCENARIO_FILE /test/locusts.py


CMD ["/usr/local/bin/run.sh"]