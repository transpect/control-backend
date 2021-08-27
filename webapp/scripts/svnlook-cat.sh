#!/bin/bash

# $1 path to repo
# $2 path in repo (must be file, not directory)
# $3 revision
# $4 tmp dir (must already exist)

target=$4/$(basename $2)

svnlook cat -r $3 $1 $2 > $target
echo -n $target
