#!/usr/bin/env bash
set -eu
apt-get update
apt-get install -y git
git config --global --add safe.directory /workspace#
cat /etc/os-release
