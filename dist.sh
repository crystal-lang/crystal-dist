#!/bin/sh
set -e

function debian() {
  docker-compose exec debian /bin/sh -c "$@"
}

function centos() {
  docker-compose exec centos /bin/sh -c "$@"
}

case $1 in
  pull)
    s3cmd -v sync s3://dist.crystal-lang.org/rpm/ dist/rpm/
    s3cmd -v sync s3://dist.crystal-lang.org/apt/ dist/apt/
    ;;

  push)
    s3cmd -v sync dist/rpm/ s3://dist.crystal-lang.org/rpm/
    s3cmd -v sync dist/apt/ s3://dist.crystal-lang.org/apt/
    ;;

  add-deb)
    debian "dpkg-sig --sign builder -m 7CC06B54 /$2"
    debian "reprepro --ask-passphrase -V --confdir /dist/apt-conf --basedir /dist/apt includedeb crystal /$2"
    ;;

  add-rpm)
    centos "rpm --resign /$2"
    centos "cp /$2 /dist/rpm"
    centos "createrepo /dist/rpm"
    centos "gpg --detach-sign --armor -u 7CC06B54 /dist/rpm/repodata/repomd.xml"
    ;;
esac
