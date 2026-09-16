#!/bin/sh
set -eu

root=$(CDPATH= cd -P "$(dirname "$0")/.." && pwd)
version=${MOSML_VERSION:-2.10.1}
url=${MOSML_URL:-https://github.com/kfl/mosml/archive/refs/tags/ver-$version.tar.gz}
sha256=${MOSML_SHA256:-}
if [ -z "$sha256" ] && [ "$version" = 2.10.1 ]; then
    sha256=fed5393668b88d69475b070999b1fd34e902591345de7f09b236824b92e4a78f
fi
test -n "$sha256" || { echo "MOSML_SHA256 is required for non-default Moscow ML versions" >&2; exit 1; }
tools=${MOSML_TOOLS_DIR:-$root/build/tools}
archive=$tools/mosml-$version.tar.gz
source=$tools/mosml-ver-$version

command -v curl >/dev/null 2>&1 || { echo "Moscow ML bootstrap requires curl" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "Moscow ML bootstrap requires sha256sum" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "Moscow ML bootstrap requires tar" >&2; exit 1; }
command -v make >/dev/null 2>&1 || { echo "Moscow ML bootstrap requires make" >&2; exit 1; }
command -v perl >/dev/null 2>&1 || { echo "Moscow ML bootstrap requires perl" >&2; exit 1; }
command -v "${MOSML_CC:-${CC:-cc}}" >/dev/null 2>&1 || {
    echo "Moscow ML bootstrap requires a C compiler" >&2
    exit 1
}

mkdir -p "$tools"
if [ ! -f "$archive" ]; then
    temporary=$archive.download.$$
    trap 'rm -f "$temporary"' EXIT HUP INT TERM
    curl -fsSL "$url" -o "$temporary"
    actual=$(sha256sum "$temporary" | awk '{print $1}')
    test "$actual" = "$sha256" || {
        echo "Moscow ML source checksum mismatch: expected $sha256, got $actual" >&2
        exit 1
    }
    mv "$temporary" "$archive"
    trap - EXIT HUP INT TERM
fi
test "$(sha256sum "$archive" | awk '{print $1}')" = "$sha256" || {
    echo "Moscow ML source checksum mismatch: $archive" >&2
    exit 1
}

if [ ! -x "$source/src/camlrunm" ] || [ ! -f "$source/src/compiler/mosmlcmp" ] ||
   [ ! -f "$source/src/compiler/mosmllnk" ]; then
    temporary=$tools/mosml-$version.extract.$$
    trap 'rm -rf "$temporary"' EXIT HUP INT TERM
    rm -rf "$temporary"
    mkdir "$temporary"
    tar -xzf "$archive" -C "$temporary"
    extracted=$(find "$temporary" -mindepth 1 -maxdepth 1 -type d -print -quit)
    test -n "$extracted"
    rm -rf "$source"
    mv "$extracted" "$source"
    rm -rf "$temporary"
    trap - EXIT HUP INT TERM
fi

if [ ! -x "$source/src/camlrunm" ] || [ ! -f "$source/src/compiler/mosmlcmp" ] ||
    [ ! -f "$source/src/compiler/mosmllnk" ] ||
    ! grep -q '^DYNLIBSUPPORT=true' "$source/src/Makefile.inc"; then
     sed -i "s#^PREFIX=.*#PREFIX=$source/install#; s#^CC=gcc#CC=${MOSML_CC:-${CC:-cc}}#; s#^DYNLIBSUPPORT=.*#DYNLIBSUPPORT=true#" "$source/src/Makefile.inc"
    make -C "$source/src" world 1>&2
fi
if [ ! -f "$source/install/lib/mosml/header" ]; then
    make -C "$source/src" install 1>&2
fi

test -x "$source/install/bin/camlrunm"
test -f "$source/install/lib/mosml/mosmlcmp"
test -f "$source/install/lib/mosml/mosmllnk"
printf '%s\n' "$source/install/bin/camlrunm" "$source/install/lib/mosml/mosmlcmp" "$source/install/lib/mosml/mosmllnk" "$source/install/lib/mosml"