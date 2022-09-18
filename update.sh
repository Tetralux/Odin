#!/bin/env fish

git checkout master &&
git pull --rebase

make -f Makefile.2 $argv
