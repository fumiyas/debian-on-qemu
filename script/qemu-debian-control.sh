#!/bin/sh

set -u

cmd_ok()
{
  echo "OK${1:+: $1}"
  echo
}

cmd_end()
{
  echo
  echo "END${1+: $1}"
}

while read -r cmd arg; do
  case "$cmd" in
  RUN_SHELL)
    cmd_ok "$cmd"
    eval "$arg" 2>&1|base64
    cmd_end "$cmd"
    ;;
  *)
    echo "NG: Unknown command"
    ;;
  esac
done

