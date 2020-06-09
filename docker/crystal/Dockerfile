ARG base_docker_image
FROM ${base_docker_image} as runtime

RUN \
  apt-get update && \
  apt-get install -y apt-transport-https gnupg2 ca-certificates && \
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 09617FD37CC06B54 && \
  echo "deb https://dist.crystal-lang.org/apt crystal main" > /etc/apt/sources.list.d/crystal.list && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -y tzdata crystal gcc pkg-config libssl-dev libxml2-dev libyaml-dev libgmp-dev git make && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

CMD ["/bin/sh"]

FROM runtime as build

RUN \
  apt-get update && \
  apt-get install -y build-essential llvm-8 lld-8 libedit-dev gdb && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN ln -sf /usr/bin/ld.lld-8 /usr/bin/ld.lld

CMD ["/bin/sh"]
