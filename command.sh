#!/usr/bin/env sh

echo "$@" | socat UNIX-CONNECT:/tmp/minyaty_control.socket -
