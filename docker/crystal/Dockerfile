ARG base_docker_image
ARG obs_repository
FROM ${base_docker_image} as runtime

RUN \
  apt-get update && \
  apt-get install -y wget gnupg2 && \
  wget -qO- https://download.opensuse.org/repositories/devel:languages:crystal/xUbuntu_20.04/Release.key | gpg --dearmor > /etc/apt/trusted.gpg.d/devel_languages_crystal.gpg && \
  echo "deb http://download.opensuse.org/repositories/devel:languages:crystal/${obs_repository}/ /" > /etc/apt/sources.list.d/devel:languages:crystal.list && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -y tzdata crystal gcc pkg-config libssl-dev libxml2-dev libyaml-dev libgmp-dev git make && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

CMD ["/bin/sh"]

FROM runtime as build

RUN \
  apt-get update && \
  apt-get install -y build-essential llvm-10 lld-10 libedit-dev gdb && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN ln -sf /usr/bin/ld.lld-10 /usr/bin/ld.lld

CMD ["/bin/sh"]
