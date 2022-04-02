#!/usr/bin/env dash

echo cycle-category "$1" | socat UNIX-CONNECT:/tmp/minyaty_control.socket -
