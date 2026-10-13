#!/bin/sh
# The directory on the Windows side where the tests of the Windows VMs run
# (tests/run-windows.sh, the rune:windows configurations of
# tests/basis/run-matrix.sh): $RUNE_WINDOWS_DIR, or one for this tree under
# rune-test-windows in the TEMP directory of Windows, as a path of this
# system. It is made if it does not exist. Prints nothing and fails when
# there is no Windows to ask.
#
# Not this tree: WSL hands an .exe a directory of Linux as a \\wsl.localhost
# path, which Windows sees as a network file system -- not NTFS, which is what
# the tests of files, links and locks are about -- and which cmd.exe refuses.
#
# One for each tree, since every worktree of the repository shares the one
# TEMP: two that ran the tests at once would empty and fill the same
# directories. It is named by the tree's directory, and a checksum of the
# tree's path tells apart two trees of one name.
dir=${RUNE_WINDOWS_DIR:-}
if [ -z "$dir" ]; then
  cmd=$(command -v cmd.exe 2> /dev/null || echo /mnt/c/Windows/System32/cmd.exe)
  # started from a directory of Windows, or cmd.exe complains about this one
  temp=$(cd /mnt/c 2> /dev/null && "$cmd" /c 'echo %TEMP%' 2> /dev/null | tr -d '\r')
  [ -n "$temp" ] || exit 1
  temp=$(wslpath -u "$temp" 2> /dev/null) || exit 1
  tree=$(cd "$(dirname "$0")/.." && pwd -P) || exit 1
  sum=$(printf '%s' "$tree" | cksum | cut -d ' ' -f 1)
  dir=$temp/rune-test-windows/$(basename "$tree")-$sum
fi
mkdir -p "$dir" 2> /dev/null || exit 1
echo "$dir"
