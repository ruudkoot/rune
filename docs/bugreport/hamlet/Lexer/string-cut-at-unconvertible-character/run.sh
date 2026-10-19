#!/bin/sh
# Run every program with HaMLet. HAMLET is the command (default: hamlet on
# the PATH), with any options it needs, such as -b and the directory of
# HaMLet's basis. HaMLet interprets each program with its own Basis
# Library, and gives "file:line.column-line.column: message" when it
# refuses one. An unpatched HaMLet also prints what it loads and the values
# it binds; those lines are left out, so that the output is the same as
# with Rune's build, which HAMLET_QUIET keeps quiet.
HAMLET=${HAMLET:-hamlet}
HAMLET_QUIET=1
export HAMLET_QUIET
cd "$(dirname "$0")"
for prog in bug bug-utf8 bug-cases bug-escape bug-equal \
            refused-first refused-char ok-escape; do
  $HAMLET "$prog.sml" 2>&1 |
    sed -e '/^\[loading standard basis library\]$/d' \
        -e '/^\[processing .*\]$/d' -e '/^val .* : /d' |
    sed "1s/^/$(printf '%-14s' "$prog")/; 2,\$s/^/              /"
done
