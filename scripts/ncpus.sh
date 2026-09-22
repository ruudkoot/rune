#!/bin/sh
# Print the number of CPUs available to this process (the default number of
# parallel jobs for make and the test scripts).
n=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null)
case "$n" in
  ''|*[!0-9]*|0) echo 1 ;;
  *) echo "$n" ;;
esac
