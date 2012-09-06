#!/usr/bin/env bash

# assume $KRAKEN points to repo

function usage {
  echo "
Usage: kraken.sh [OPTIONS] <input.krn>

Generate Coq code and proofs from a Kraken kernel spec.

OPTIONS:
  -h, --help        print this usage information
  -f, --force       overwrite any existing output
"
  exit 1
}

# http://snipplr.com/view/18026/canonical-absolute-path/
function canonpath () { 
  echo $(cd -P $(dirname "$1"); pwd -P)/$(basename "$1")
}

# arg defaults
FORCE=false
KRN=""

# process args
while [ "$*" != "" ]; do
  case $1 in
    "-f" | "--force")
      FORCE=true
      ;;
    "-h" | "-help" | "--help")
      usage
      ;;
    *.krn)
      KRN=$1
      ;;
    *)
      echo "Error: unrecognized option '$1'"
      usage
      ;;
  esac
  shift
done

if [ ! -f "$KRN" ]; then
  echo "Error: cannot find input '$KRN'"
  exit 1
fi
KRN=$(canonpath "$KRN")

# setup output dir
cd $KRAKEN/scratch
D=$(basename $KRN .krn)
if $FORCE; then
  rm -rf $D
elif [ -d $D ]; then
  echo "Error: '$D' already exists."
  echo "To overwrite, use the --force option."
  exit 1
fi
cp -r $KRAKEN/kernel-template $D

# generate code and proofs
$KRAKEN/bin/kraken $KRN \
  --turn $D/coq/Turn.v \
  --pylib $D/py/kraken_msg_lib.py

# build the monster
make -C $D
