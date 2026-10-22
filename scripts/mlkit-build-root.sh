#!/bin/sh
# Keep native compiler/tool caches separate from library-test contexts.
# A changed generated configuration invalidates this private source view;
# the installed MLKit Basis cache and the original sources are untouched.
set -eu
cd "$(dirname "$0")/.."
group=$1
case "$group" in build/*-mlkit.mlb) ;; *) echo "mlkit-build-root: expected a generated MLKit group" >&2; exit 1 ;; esac
case "${group#build/}" in */*) echo "mlkit-build-root: expected a group directly under build" >&2; exit 1 ;; esac
[ -f "$group" ] || { echo "mlkit-build-root: no $group" >&2; exit 1; }
[ -f build/config.sml ] || { echo "mlkit-build-root: no generated configuration" >&2; exit 1; }
root=build/mlkit-root
if ! cmp -s build/config.sml "$root/configuration.sml"; then
  rm -rf "$root"
fi
mkdir -p "$root/build"
copy() {
  if ! cmp -s "$1" "$2"; then cp "$1" "$2"; fi
}
copy "$group" "$root/$group"
dir=$(dirname "$group")
awk '
  /^[ \t]*(\$\(|\(\*)/ { next }
  {
    sub(/^[ \t]+/, "")
    sub(/[ \t]+$/, "")
    if ($0 != "") print
  }
' "$group" | while IFS= read -r rel; do
  case "$rel" in
    config.sml) dest=build/config.sml ;;
    ../lib/*|../src/*|../tools/*) dest=${rel#../} ;;
    *) echo "mlkit-build-root: unsupported generated source path: $rel" >&2; exit 1 ;;
  esac
  case "/$dest/" in
    */../*|*/./*) echo "mlkit-build-root: source escapes its view: $rel" >&2; exit 1 ;;
  esac
  mkdir -p "$(dirname "$root/$dest")"
  copy "$dir/$rel" "$root/$dest"
done
cp build/config.sml "$root/configuration.sml.tmp.$$"
mv -f "$root/configuration.sml.tmp.$$" "$root/configuration.sml"
printf '%s\n' "$root/$group"
