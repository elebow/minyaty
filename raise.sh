#!/usr/bin/env dash

echo raise-window "$1" | socat UNIX-CONNECT:/tmp/minyaty_control.socket -
