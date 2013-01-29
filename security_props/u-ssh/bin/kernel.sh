#!/usr/bin/env bash

export KROOT="/home/daniel/Dropbox/PL/ssh/u-ssh"
export PYTHONPATH="$PYTHONPATH:$KROOT/lib/python2.7/site-packages"

# remove old logs
rm -f $KROOT/log/*-log

EXEC="$KROOT/bin/.Main"
if [ "$1" = "--debug" ]; then
  EXEC="ocamldebug -I $KROOT/ml/_build $EXEC"
fi
$EXEC