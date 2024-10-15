#!/usr/bin/env bash

version=$(git describe --exact-match --tags || echo 'v0.0.0')

exec sed \
  -e "s:@VERSION@:${version/v/}:g" \
  src/config.zig.in \
  > src/config.zig
