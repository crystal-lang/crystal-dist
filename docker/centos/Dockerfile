FROM centos

RUN yum install -y rpm-sign createrepo

RUN echo "%_signature gpg" > ~/.rpmmacros
RUN echo "%_gpg_name 7CC06B54" >> ~/.rpmmacros

CMD \
  gpg-agent --daemon --pinentry-program=/usr/bin/pinentry-curses \
            --use-standard-socket; \
  while gpg-connect-agent /bye; do \
    sleep 2; \
  done
