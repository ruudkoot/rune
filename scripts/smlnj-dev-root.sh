#!/bin/sh
# Lay out a tree of symlinks whose CM metadata is not the 110.99.9 compilers'.
#   scripts/smlnj-dev-root.sh CMFILE
# CMFILE is build/<prog>.cm. SML/NJ 2026.2 writes its binfiles in .cm, the
# same directory name 110.99.9 uses, and that name is fixed in its heap, so
# the two compilers cannot share a source tree. The copy of the group file
# and the symlinks live under build/smlnj-dev-root, and the path of the
# group's copy is printed.
# A symlink is what CM is given, and it writes .cm beside that symlink, not
# beside the file the symlink names.
set -eu
cd "$(dirname "$0")/.."
cm=$1
[ -f "$cm" ] || { echo "smlnj-dev-root: no $cm" >&2; exit 1; }
root=build/smlnj-dev-root
# One tree for every dev build. Recreate the group file each time; the
# symlinks stay, and a source that is new since the last run is added.
mkdir -p "$root/build"
cp "$cm" "$root/$cm"
ln -sfn "$(pwd)/build/config.sml" "$root/build/config.sml"
# Paths in the group are relative to the directory of the group file.
dir=$(dirname "$cm")
awk '
  /^[ \t]*(\$\(|\$\/|#|\(\*)/ { next }
  /^Group/ { next }
  {
    sub(/^[ \t]+/, "")
    sub(/[ \t]+$/, "")
    if ($0 == "" || $0 ~ /[ \t]/) next
    print
  }
' "$cm" | while IFS= read -r rel; do
  [ "$rel" = config.sml ] && continue
  src=$(cd "$dir" && pwd)/$rel
  # the path CM will open, relative to the repository
  dest=$root/$dir/$rel
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
done
echo "$root/$cm"
