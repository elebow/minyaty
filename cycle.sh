#!/usr/bin/env dash

echo cycle-category "$1" | socat UNIX-CONNECT:/tmp/crystal_windows_control.socket -
