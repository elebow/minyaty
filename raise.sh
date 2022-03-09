#!/usr/bin/env dash

echo raise-window "$1" | socat UNIX-CONNECT:/tmp/crystal_windows_control.socket -
