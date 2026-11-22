#!/bin/bash
# check_release.sh - Check that a release tag matches common/VERSION.
#
# Usage: tests/check_release.sh <tag>      (e.g. tests/check_release.sh v6.1.0)
#
# The tag must be "v" plus the content of common/VERSION, and the version must
# not be a development version (-dev), because the clients send the version to
# the server. The VERSION file can be given with the second argument (for
# tests).

here=$(cd "$(dirname "$0")" && pwd) || exit 2
tag=${1:-}
file=${2:-$here/../common/VERSION}

if [ -z "$tag" ]; then
  echo "Usage: $0 <tag>" 1>&2
  exit 2
fi

# shellcheck disable=SC1091
. "$here/../common/sindan_funcb.sh" || exit 2
version=$(read_version "$file") || exit 1

case $version in
  *-dev*)
    echo "ERROR: $version is a development version. Remove -dev from common/VERSION before the release." 1>&2
    exit 1
    ;;
esac

if [ "$tag" != "v$version" ]; then
  echo "ERROR: the tag $tag does not match common/VERSION ($version). Expected v$version." 1>&2
  exit 1
fi

echo "OK: $tag matches common/VERSION."
