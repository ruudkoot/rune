#!/bin/sh
# The distribution archives (scripts/make-dist.py, docs/building.md,
# Distribution) with stand-in binaries: the members, the installer, and the
# ELF and PE checks. When cmd.exe is here, install.bat is run with
# --no-register so it does not touch the registry.
set -u
cd "$(dirname "$0")/../.."
root=$(pwd)
out=$root/tests/out/dist
rm -rf "$out"
mkdir -p "$out"
pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { echo "FAIL dist.$*"; fail=$((fail + 1)); }

python3 scripts/make-dist.py --self-test || bad "self-test"

# a library the way lib/ is: library.build, a MANIFEST, and a decoy the
# archive must not carry
fix=$out/lib
mkdir -p "$fix/basis" "$fix/json/pkg" "$fix/cache"
printf '%s\n' '# a comment' 'list.sml | demand | yes | List | ' > "$fix/basis/MANIFEST"
printf '%s\n' 'structure List = struct end' > "$fix/basis/list.sml"
printf '%s\n' '# Basis' > "$fix/basis/README.md"
printf '%s\n' 'files list.sml end' > "$fix/basis/library.build"
printf '%s\n' 'json.sml | demand | yes | Json | ' 'pkg/extra.sml | demand | yes | | ' > "$fix/json/MANIFEST"
printf '%s\n' 'structure Json = struct end' > "$fix/json/json.sml"
printf '%s\n' 'structure Extra = struct end' > "$fix/json/pkg/extra.sml"
printf '%s\n' '# Json' > "$fix/json/README.md"
printf '%s\n' 'files json.sml end' > "$fix/json/library.build"
printf '%s\n' 'not a library' > "$fix/stray.sml"
printf '%s\n' 'cached' > "$fix/cache/made"
printf '%s\n' 'compiler' > "$out/rune.rbc"
printf '%s\n' 'repl' > "$out/rune-repl.img"
for arch in x86_64 i686 aarch64 ppc64; do
  printf 'vm-%s\n' "$arch" > "$out/vm-$arch"
done
for arch in x86_64 i686; do
  printf 'exe-%s\n' "$arch" > "$out/exe-$arch"
done

pack() { # args...
  python3 scripts/make-dist.py --version test1 --out "$out/archives" --lib "$fix" \
    --license LICENSE --compiler "$out/rune.rbc" --repl "$out/rune-repl.img" \
    --linux x86_64="$out/vm-x86_64" --linux i686="$out/vm-i686" \
    --linux aarch64="$out/vm-aarch64" --linux ppc64="$out/vm-ppc64" \
    --windows x86_64="$out/exe-x86_64" --windows i686="$out/exe-i686" \
    "$@" > "$out/pack.out" 2> "$out/pack.err"
}

if pack --fixture; then ok
else bad "pack: $(cat "$out/pack.err")"; echo "dist: passed $pass, failed $fail"; exit 1
fi

linux=$out/archives/rune-test1-linux.tar.gz
windows=$out/archives/rune-test1-windows.zip
[ -f "$linux" ] && [ -f "$windows" ] && ok || bad "archive names"

top=rune-test1-linux
cat > "$out/expect-linux" << EOF
$top/LICENSE
$top/VERSION
$top/install.sh
$top/lib/rune/basis/MANIFEST
$top/lib/rune/basis/README.md
$top/lib/rune/basis/list.sml
$top/lib/rune/json/MANIFEST
$top/lib/rune/json/README.md
$top/lib/rune/json/json.sml
$top/lib/rune/json/pkg/extra.sml
$top/lib/rune/rune-repl.img
$top/lib/rune/rune.rbc
$top/runtime/aarch64/runevm
$top/runtime/i686/runevm
$top/runtime/ppc64/runevm
$top/runtime/x86_64/runevm
EOF
python3 - "$linux" "$out/expect-linux" "$out/members" << 'PY'
import sys, tarfile
tar = tarfile.open(sys.argv[1], "r:gz")
names = sorted(m.name for m in tar.getmembers() if m.isfile())
open(sys.argv[3], "w").write("".join(n + "\n" for n in names))
want = [ln for ln in open(sys.argv[2]) if ln.strip()]
got = [n + "\n" for n in names]
sys.exit(0 if got == want else 1)
PY
if [ $? = 0 ]; then ok; else bad "linux members: $(cat "$out/members")"; fi

python3 - "$linux" << 'PY'
import sys, tarfile
tar = tarfile.open(sys.argv[1], "r:gz")
bad = []
for m in tar.getmembers():
    if not m.isfile():
        continue
    mode = m.mode & 0o777
    name = m.name.split("/", 1)[1]
    want = 0o755 if name == "install.sh" or name.startswith("runtime/") else 0o644
    if mode != want or m.uid != 0 or m.gid != 0 or m.mtime != 0:
        bad.append(f"{name} mode={mode:o} uid={m.uid} mtime={m.mtime}")
    if name.endswith(".sh") or name.endswith(".sml") or name == "VERSION":
        data = tar.extractfile(m).read()
        if b"\r" in data:
            bad.append(f"{name} has CR")
sys.exit(0 if not bad else 1)
PY
if [ $? = 0 ]; then ok; else bad "linux modes"; fi

# the windows zip: both runtimes, the installer, CRLF batch files, no vm/
wtop=rune-test1-windows
cat > "$out/expect-windows" << EOF
$wtop/LICENSE
$wtop/VERSION
$wtop/install.bat
$wtop/lib/rune/basis/MANIFEST
$wtop/lib/rune/basis/README.md
$wtop/lib/rune/basis/list.sml
$wtop/lib/rune/json/MANIFEST
$wtop/lib/rune/json/README.md
$wtop/lib/rune/json/json.sml
$wtop/lib/rune/json/pkg/extra.sml
$wtop/lib/rune/rune-repl.img
$wtop/lib/rune/rune.rbc
$wtop/register.ps1
$wtop/runtime/i686/runevm.exe
$wtop/runtime/x86_64/runevm.exe
$wtop/share/rune.ico
$wtop/uninstall.bat
$wtop/wrappers/rune-repl.cmd
$wtop/wrappers/rune.cmd
EOF
python3 - "$windows" "$out/expect-windows" "$out/wmembers" << 'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
names = sorted(i.filename for i in z.infolist())
open(sys.argv[3], "w").write("".join(n + "\n" for n in names))
want = [ln for ln in open(sys.argv[2]) if ln.strip()]
got = [n + "\n" for n in names]
if got != want:
    sys.exit(1)
for i in z.infolist():
    name = i.filename.split("/", 1)[1]
    data = z.read(i)
    if name.endswith(".bat") or name.endswith(".cmd"):
        if b"\r\n" not in data or b"\n" in data.replace(b"\r\n", b""):
            sys.exit(2)
    if name.startswith("runtime/") and not data.startswith(b"exe-"):
        sys.exit(3)
    if name == "share/rune.ico" and not data.startswith(b"\x00\x00\x01\x00"):
        sys.exit(4)
sys.exit(0)
PY
rc=$?
if [ $rc = 0 ]; then ok
elif [ $rc = 2 ]; then bad "windows batch files are not CRLF"
elif [ $rc = 3 ]; then bad "windows runtime bytes"
elif [ $rc = 4 ]; then bad "windows icon is not an .ico"
else bad "windows members: $(cat "$out/wmembers")"; fi

# a library with no MANIFEST is refused, and so is a version with a slash
only=$out/nomanifest/lib
mkdir -p "$only/gone"
printf '%s\n' 'files end' > "$only/gone/library.build"
if python3 scripts/make-dist.py --fixture --version test1 --out "$out/archives" --lib "$only" \
    --license LICENSE --compiler "$out/rune.rbc" --repl "$out/rune-repl.img" \
    --linux x86_64="$out/vm-x86_64" --linux i686="$out/vm-i686" \
    --linux aarch64="$out/vm-aarch64" --linux ppc64="$out/vm-ppc64" \
    --windows x86_64="$out/exe-x86_64" --windows i686="$out/exe-i686" \
    > "$out/nomanifest.out" 2> "$out/nomanifest.err"; then
  bad "packed a library with no MANIFEST"
else
  grep -q MANIFEST "$out/nomanifest.err" && ok || bad "missing MANIFEST: $(cat "$out/nomanifest.err")"
fi

if python3 scripts/make-dist.py --fixture --version '../x' --out "$out/archives" --lib "$fix" \
    --license LICENSE --compiler "$out/rune.rbc" --repl "$out/rune-repl.img" \
    --linux x86_64="$out/vm-x86_64" --linux i686="$out/vm-i686" \
    --linux aarch64="$out/vm-aarch64" --linux ppc64="$out/vm-ppc64" \
    --windows x86_64="$out/exe-x86_64" --windows i686="$out/exe-i686" \
    > /dev/null 2> "$out/badver.err"; then
  bad "a version with a slash was accepted"
else
  ok
fi

mkdir -p "$out/tree"
tar -xzf "$linux" -C "$out/tree"
stage=$out/tree/$top
chmod 755 "$stage/install.sh"
prefix=$out/installed

got=$("$stage/install.sh" --dry-run)
want=$(printf 'prefix=%s\narch=%s\n' "$HOME/.local" "$(
  machine=$(uname -m); bits=$(getconf LONG_BIT)
  case "$machine" in
    x86_64|amd64) if [ "$bits" = 32 ]; then echo i686; else echo x86_64; fi ;;
    i386|i686) echo i686 ;;
    aarch64|arm64) echo aarch64 ;;
    ppc64) echo ppc64 ;;
    *) echo "$machine" ;;
  esac
)")
[ "$got" = "$want" ] && ok || bad "dry-run as the current user printed [$got], wanted [$want]"

got=$(RUNE_DIST_EUID=0 "$stage/install.sh" --dry-run)
[ "$got" = "$(printf 'prefix=%s\narch=%s\n' /usr/local "$(printf '%s\n' "$want" | sed -n 's/^arch=//p')")" ] \
  && ok || bad "dry-run as root printed [$got]"

if "$stage/install.sh" --dry-run --arch ppc64le > "$out/le.out" 2> "$out/le.err"; then
  bad "ppc64le was accepted"
else
  grep -q ppc64le "$out/le.err" && ok || bad "ppc64le: $(cat "$out/le.err")"
fi
if "$stage/install.sh" --dry-run --arch armv7l > /dev/null 2> "$out/arm.err"; then
  bad "armv7l was accepted"
else
  ok
fi

if "$stage/install.sh" --prefix "$prefix" --arch aarch64 > "$out/install.out" 2> "$out/install.err"; then
  ok
else
  bad "install: $(cat "$out/install.err")"
fi
cmp -s "$stage/runtime/aarch64/runevm" "$prefix/bin/runevm" && ok || bad "installed VM is not the aarch64 runtime"
cmp -s "$fix/basis/list.sml" "$prefix/lib/rune/basis/list.sml" && ok || bad "basis was not installed"
cmp -s "$fix/json/pkg/extra.sml" "$prefix/lib/rune/json/pkg/extra.sml" && ok || bad "json was not installed"
[ ! -e "$prefix/lib/rune/basis/library.build" ] && ok || bad "library.build was installed"
[ ! -e "$prefix/lib/rune/cache" ] && ok || bad "the cache was installed"
grep -q "$root" "$prefix/bin/rune" && bad "rune names the tree" || ok
grep -q "$out" "$prefix/bin/rune" && bad "rune names the archive" || ok
grep -q "note: $prefix/bin is not on your PATH" "$out/install.out" && ok || bad "no PATH note"

cat > "$out/want-rune" << 'EOF'
#!/bin/sh
d=$(dirname "$0")
[ "$1" = -i ] && shift && exec "$d/rune-repl" "$@"
exec "$d/runevm" --heap-size 67108864 "$d/../lib/rune/rune.rbc" --lib "$d/../lib/rune" "$@"
EOF
cat > "$out/want-repl" << 'EOF'
#!/bin/sh
d=$(dirname "$0")
exec "$d/runevm" --heap-size 67108864 --restore "$d/../lib/rune/rune-repl.img" -- "$@"
EOF
cmp -s "$out/want-rune" "$prefix/bin/rune" && ok || bad "rune wrapper"
cmp -s "$out/want-repl" "$prefix/bin/rune-repl" && ok || bad "rune-repl wrapper"

# a second install replaces the VM
if "$stage/install.sh" --prefix "$prefix" --arch ppc64 > /dev/null 2> "$out/reinstall.err"; then
  cmp -s "$stage/runtime/ppc64/runevm" "$prefix/bin/runevm" && ok || bad "reinstall left the old VM"
else
  bad "reinstall: $(cat "$out/reinstall.err")"
fi

if "$stage/install.sh" --prefix "$prefix" --uninstall > "$out/uninstall.out" 2> "$out/uninstall.err"; then
  if [ -e "$prefix" ]; then bad "uninstall left $prefix"; else ok; fi
else
  bad "uninstall: $(cat "$out/uninstall.err")"
fi
if "$stage/install.sh" --prefix "$prefix" --uninstall > "$out/uninstall2.out" 2> "$out/uninstall2.err"; then
  grep -q "nothing installed" "$out/uninstall2.out" && ok || bad "second uninstall: $(cat "$out/uninstall2.out")"
else
  bad "second uninstall failed"
fi

# header check, on the packager's path: real headers pack, a script does not
python3 - "$out" << 'PY'
import importlib.util, pathlib, sys
out = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("make_dist", "scripts/make-dist.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
samples = {
    "x86_64": mod._elf_file("x86_64", "/lib64/ld-linux-x86-64.so.2", ["libc.so.6"]),
    "i686": mod._elf_file("i686", "/lib/ld-linux.so.2", ["libc.so.6"]),
    "aarch64": mod._elf_file("aarch64", "/lib/ld-linux-aarch64.so.1", ["libc.so.6"]),
    "ppc64": mod._elf_file("ppc64", "/lib64/ld64.so.1", ["libc.so.6"]),
}
for arch, data in samples.items():
    (out / f"good-{arch}").write_bytes(data)
(out / "good-win64").write_bytes(mod._pe_file(mod.PE_AMD64))
(out / "good-win32").write_bytes(mod._pe_file(mod.PE_I386))
PY
if python3 scripts/make-dist.py --version test1 --out "$out/checked" --lib "$fix" \
    --license LICENSE --compiler "$out/rune.rbc" --repl "$out/rune-repl.img" \
    --linux x86_64="$out/good-x86_64" --linux i686="$out/good-i686" \
    --linux aarch64="$out/good-aarch64" --linux ppc64="$out/good-ppc64" \
    --windows x86_64="$out/good-win64" --windows i686="$out/good-win32" \
    > /dev/null 2> "$out/checked.err"; then
  ok
else
  bad "headers: $(cat "$out/checked.err")"
fi
printf '%s\n' '#!/bin/sh' 'echo no' > "$out/script-vm"
if python3 scripts/make-dist.py --version test1 --out "$out/checked" --lib "$fix" \
    --license LICENSE --compiler "$out/rune.rbc" --repl "$out/rune-repl.img" \
    --linux x86_64="$out/script-vm" --linux i686="$out/good-i686" \
    --linux aarch64="$out/good-aarch64" --linux ppc64="$out/good-ppc64" \
    --windows x86_64="$out/good-win64" --windows i686="$out/good-win32" \
    > /dev/null 2> "$out/script.err"; then
  bad "a script was packed as a runtime"
else
  grep -q script "$out/script.err" && ok || bad "script runtime: $(cat "$out/script.err")"
fi

# cmd.exe refuses a UNC current directory, so this runs on the Windows side
if command -v cmd.exe > /dev/null 2>&1 && windir=$(sh tests/windows-dir.sh 2> /dev/null); then
  stagew=$windir/dist-test
  rm -rf "$stagew"
  mkdir -p "$stagew"
  python3 - "$windows" "$stagew" << 'PY'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
  if ( cd "$stagew/$wtop" && cmd.exe /c "install.bat --prefix ..\\prefix --arch x86_64 --no-register" ) \
      > "$out/cmd.out" 2> "$out/cmd.err" < /dev/null \
      && cmp -s "$out/exe-x86_64" "$stagew/prefix/bin/runevm.exe" \
      && [ -f "$stagew/prefix/share/rune.ico" ]; then
    ok
    if ( cd "$stagew/prefix" && cmd.exe /c uninstall.bat ) > "$out/cmd-un.out" 2> "$out/cmd-un.err" \
        && [ ! -e "$stagew/prefix" ]; then
      ok
    else
      bad "windows uninstall left $(find "$stagew/prefix" -print 2> /dev/null | head)"
    fi
  else
    bad "install.bat: $(sed 's/\r$//' "$out/cmd.err" "$out/cmd.out" | head -8)"
  fi
  rm -rf "$stagew"
fi

if [ "$fail" != 0 ]; then echo "dist: passed $pass, failed $fail"; fi
[ "$fail" = 0 ]
