#!/bin/sh
set -e

function debian() {
  docker-compose exec debian /bin/sh -c "$@"
}

function centos() {
  docker-compose exec centos /bin/sh -c "$@"
}

function aws_cli() {
  docker run --rm \
    -e "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" \
    -e "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" \
    -v "$(pwd)/dist:/dist" \
    mesosphere/aws-cli $@
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

  # Upload docs in .tar.gz file to https://crystal-lang.org/api/{version}
  #
  # $ ./dist.sh push-docs {version} {path-to-docs.tar.gz}
  push-docs)
    rm -rf dist/api/$2
    mkdir -p dist/api/$2
    tar xfz $3 -C dist/api/$2 --strip-component=2
    s3cmd -v sync dist/api/$2/ s3://crystal-api/api/$2/
    ;;

  # Make {version} the default docs version so the following redirects occurs
  # /api/latest/Array.html -> /api/{version}/Array.html
  # /api/Array.html        -> /api/{version}/Array.html
  #
  # Requires AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
  #
  # $ ./dist.sh redirect-docs {version}
  redirect-docs)
    cat - > dist/api/.aws-config <<EOF
    {
      "IndexDocument": {
        "Suffix": "index.html"
      },
      "RoutingRules": [
        {
          "Condition": {
            "KeyPrefixEquals": "api/latest/$2/"
          },
          "Redirect": {
            "HttpRedirectCode": "302",
            "ReplaceKeyWith": "404",
            "Protocol": "https",
            "HostName": "crystal-lang.org"
          }
        },
        {
          "Condition": {
            "KeyPrefixEquals": "api/latest/"
          },
          "Redirect": {
            "HttpRedirectCode": "302",
            "ReplaceKeyPrefixWith": "api/$2/",
            "Protocol": "https",
            "HostName": "crystal-lang.org"
          }
        },
        {
          "Condition": {
            "KeyPrefixEquals": "api/",
            "HttpErrorCodeReturnedEquals": "404"
          },
          "Redirect": {
            "HttpRedirectCode": "301",
            "ReplaceKeyPrefixWith": "api/latest/",
            "Protocol": "https",
            "HostName": "crystal-lang.org"
          }
        }
      ]
    }
EOF
    aws_cli "s3api put-bucket-website --bucket crystal-api --website-configuration file:///dist/api/.aws-config"
    ;;

esac
