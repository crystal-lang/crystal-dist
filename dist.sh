#!/bin/bash
set -e

function debian() {
  docker-compose exec debian /bin/sh -c "$@"
}

function centos() {
  docker-compose exec centos /bin/sh -c "$@"
}

function assert_installed_crystal_in_docker() {
  INSTALLED_VERSION=$(docker run --rm crystallang/crystal:$1 crystal --version | head -n 1)
  if [[ $INSTALLED_VERSION =~ "Crystal $2 " ]];
    then
      echo " ✓ Docker images crystallang/crystal:$1 matches Crystal $2";
    else
      echo "ERROR: installed crystal version does not match docker tag"
      echo "  Expected: Crystal $2"
      echo "    Actual: $INSTALLED_VERSION"
      exit 1
  fi
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
    s3cmd -v sync --no-delete-removed --exclude=.DS_Store -P dist/rpm/ s3://dist.crystal-lang.org/rpm/
    s3cmd -v sync --no-delete-removed --exclude=.DS_Store -P dist/apt/ s3://dist.crystal-lang.org/apt/
    ;;

  add-deb)
    debian "dpkg-sig --sign builder -m 7CC06B54 /$2"
    debian "reprepro --ask-passphrase -V --confdir /dist/apt-conf --basedir /dist/apt includedeb crystal /$2"
    ;;

  add-rpm)
    centos "rpm --checksig /$2"
    centos "rpm --resign /$2"
    centos "rpm --checksig /$2"
    centos "cp /$2 /dist/rpm"
    centos "createrepo /dist/rpm"
    centos "gpg --detach-sign --armor -u 7CC06B54 /dist/rpm/repodata/repomd.xml"
    ;;

  # Build crystallang/crystal:{version} and crystallang/crystal:{version}-build
  # docker images. They contain the published binary packages from OBS.
  #
  # $ ./dist.sh build-docker {version}
  build-docker)
    BUILD_ARGS_64='-f docker/crystal/Dockerfile --build-arg base_docker_image=ubuntu:20.04 --build-arg obs_repository=xUbuntu_20.04'
    docker build --no-cache --pull --target build -t crystallang/crystal:$2-build $BUILD_ARGS_64 .
    docker build --target runtime -t crystallang/crystal:$2 $BUILD_ARGS_64 .

    BUILD_ARGS_32='-f docker/crystal/Dockerfile --build-arg base_docker_image=i386/ubuntu:bionic --build-arg obs_repository=xUbuntu_18.04'
    docker build --no-cache --pull --target build -t crystallang/crystal:$2-i386-build $BUILD_ARGS_32 .
    docker build --target runtime -t crystallang/crystal:$2-i386 $BUILD_ARGS_32 .

    assert_installed_crystal_in_docker "$2-build" $2
    assert_installed_crystal_in_docker "$2-i386-build" $2
    ;;

  # Push local built crystallang/crystal:{version} and crystallang/crystal:{version}-build
  # docker images to hub.docker.com.
  #
  # $ ./dist.sh push-docker {version}
  push-docker)
    assert_installed_crystal_in_docker "$2-build" $2
    assert_installed_crystal_in_docker "$2-i386-build" $2

    docker push crystallang/crystal:$2
    docker push crystallang/crystal:$2-build
    docker push crystallang/crystal:$2-i386
    docker push crystallang/crystal:$2-i386-build
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

  # Update config file listing all Crystal versions available on API docs.
  # File is available at https://crystal-lang.org/api/versions.json
  #
  # $ ./dist.sh update-docs-versions {path-to-crystal-repo-working-dir}
  update-docs-versions)
    mkdir -p dist/api
    sh -c "cd $2; scripts/docs-versions.sh" > dist/api/versions.json
    s3cmd -v sync dist/api/versions.json s3://crystal-api/api/versions.json
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
