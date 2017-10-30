#!/bin/bash
#
# Keep track of benchmark data provenance.
#
# Usage:
#   ./id.sh <function name>

set -o nounset
set -o pipefail
set -o errexit

# TODO: add benchmark labels/hashes for osh and all other shells
#
# Need to archive labels too.
#
# TODO: How do I make sure the zsh label is current?  Across different
# machines?
#
# What happens when zsh is silently upgraded?
# I guess before every benchmark, you have to run the ID collection.  Man
# that is a lot of code.
#
# Should I make symlinks to the published location?
#
# Maybe bash/dash/mksh/zsh should be invoked through a symlink?
# Every symlink is a shell runtime version, and it has an associated
# toolchain?

# Platform is ambient?
# _tmp/
#   shell-id/
#     bash/
#       HASH.txt
#       version.txt
#     dash/
#       HASH.txt
#       version.txt
#   platform-id/
#     lisa/
#       HASH.txt
#       cpuinfo.txt
#       cpuinfo.txt

# ../benchmark-data/
#   shell-id/
#     bash-$HASH/
#     osh-$HASH/   # osh-cpython, osh-ovm?   osh-opy-ovm?  Too many dimensions.
#                # the other shells don't have this?
#     zsh-$HASH/
#   platform-id/
#     lisa-$HASH/

die() {
  echo "FATAL: $@" 1>&2
  exit 1
}

dump-shell-id() {
  local sh=$1  # path to the shell

  local name
  name=$(basename $sh)

  local out_dir=${2:-_tmp/shell-id/$name}
  mkdir -p $out_dir

  # Add extra repository info for osh.
  case $sh in
    bin/osh|_bin/osh)
      local branch
      branch=$(git rev-parse --abbrev-ref HEAD)
      echo $branch > $out_dir/git-branch.txt
      git rev-parse $branch > $out_dir/git-commit-hash.txt
      ;;
  esac

  case $name in
    bash|zsh|osh)
      $sh --version > $out_dir/version.txt
      ;;
    dash|mksh)
      # These don't have version strings!
      dpkg -s $name | egrep '^Package|Version' > $out_dir/version.txt
      ;;
    *)
      die "Invalid shell '$name'"
      ;;
  esac
}

# Writes a short ID to stdout.
publish-shell-id() {
  local src=$1  # e.g. _tmp/shell-id/osh
  local dest_base=${2:-../benchmark-data/shell-id}

  local name=$(basename $src)
  local hash
  hash=$(cat $src/version.txt | md5sum)  # not secure, an identifier

  local id="$name-${hash:0:8}"
  local dest="$dest_base/$id"

  mkdir -p $dest
  cp --no-target-directory --recursive $src/ $dest/

  echo $hash > $dest/HASH.txt

  ls -l $dest 1>&2

  echo $id
}

# Events that will change the env for a given machine:
# - kernel upgrade
# - distro upgrade

# How about ~/git/oilshell/benchmark-data/platform-id/lisa-$HASH
# How to calculate the hash though?

dump-if-exists() {
  local path=$1
  local out=$2
  test -f $path || return
  cat $path > $out
}

dump-platform-id() {
  local out_dir=${1:-_tmp/platform-id/$(hostname)}

  mkdir -p $out_dir

  hostname > $out_dir/hostname.txt

  # does it make sense to do individual fields like -m?
  # avoid parsing?
  # We care about the kernel and the CPU architecture.
  # There is a lot of redundant information there.
  uname -m > $out_dir/machine.txt
  # machine
  { uname --kernel-release 
    uname --kernel-version
  } > $out_dir/kernel.txt

  dump-if-exists /etc/lsb-release $out_dir/lsb-release.txt

  cat /proc/cpuinfo > $out_dir/cpuinfo.txt
  # mem info doesn't make a difference?  I guess it's just nice to check that
  # it's not swapping.  But shouldn't be part of the hash.
  cat /proc/meminfo > $out_dir/meminfo.txt

  head $out_dir/*
}

# There is already concept of the triple?
# http://wiki.osdev.org/Target_Triplet
# It's not exactly the same as what we need here, but close.

_platform-id-hash() {
  local src=$1

  # Don't hash CPU or memory
  #cat $src/cpuinfo.txt
  #cat $src/hostname.txt  # e.g. lisa

  cat $src/machine.txt  # e.g. x86_64 
  cat $src/kernel.txt

  # OS
  test -f $src/lsb-release.txt && cat $src/lsb-release.txt
}

# Writes a short ID to stdout.
publish-platform-id() {
  local src=$1  # e.g. _tmp/platform-id/lisa
  local dest_base=${2:-../benchmark-data/platform-id}

  local name=$(basename $src)
  local hash
  hash=$(_platform-id-hash $src | md5sum)  # not secure, an identifier

  local id="$name-${hash:0:8}"
  local dest="$dest_base/$id"

  mkdir -p $dest
  cp --no-target-directory --recursive $src/ $dest/

  echo $hash > $dest/HASH.txt

  ls -l $dest 1>&2
  echo $id
}

"$@"
