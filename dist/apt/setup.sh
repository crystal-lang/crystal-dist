#!/usr/bin/env bash
curl -L https://keybase.io/crystal/pgp_keys.asc | apt-key add -
echo "deb https://dist.crystal-lang.org/apt crystal main" > /etc/apt/sources.list.d/crystal.list
apt-get update
