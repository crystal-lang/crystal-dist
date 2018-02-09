FROM ubuntu:xenial as runtime

RUN \
  apt-get update && \
  apt-get install -y apt-transport-https && \
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 09617FD37CC06B54 && \
  echo "deb https://dist.crystal-lang.org/apt crystal main" > /etc/apt/sources.list.d/crystal.list && \
  apt-get update && \
  apt-get install -y crystal gcc pkg-config libssl-dev libxml2-dev libyaml-dev libgmp-dev git make && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

CMD ["/bin/bash"]

FROM runtime as build

RUN \
  apt-get update && \
  apt-get install -y build-essential llvm-4.0 libedit-dev libreadline-dev gdb && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LIBRARY_PATH=/usr/lib/crystal/lib/

CMD ["/bin/bash"]
