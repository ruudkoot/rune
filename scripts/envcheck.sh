#!/bin/sh
# Report on the machine this runs on: what it is, what it can do and how fast
# it is (docs/envcheck.md). Nothing is installed and nothing outside a
# temporary directory is written; the measurements are scripts/envcheck.c,
# compiled here.
#   scripts/envcheck.sh [--slow] [--commit-test] [--json FILE] [--markdown]
#   --slow         take a few minutes for steadier figures (default: under
#                  a minute)
#   --commit-test  last of all, allocate memory until the kernel stops it:
#                  this can get the shell's processes killed or restart the
#                  container, so it runs only when asked for
#   --json FILE    also write every result to FILE
#   --markdown     also print an entry in the form of cloud/ENVIRONMENT.md,
#                  to be checked and added by hand
# Exit status: 0 when every part ran, 2 when some could not (the report says
# which, and what to do), 1 on a usage error.
set -u
mode=fast
commit=0
json=""
markdown=0
while [ $# -gt 0 ]; do
  case "$1" in
    --slow) mode=slow; shift ;;
    --fast) mode=fast; shift ;;
    --commit-test) commit=1; shift ;;
    --json) json=$2; shift 2 ;;
    --markdown) markdown=1; shift ;;
    *) echo "usage: scripts/envcheck.sh [--slow] [--commit-test] [--json FILE] [--markdown]" >&2; exit 1 ;;
  esac
done
case "$json" in ""|/*) ;; *) json=$(pwd)/$json ;; esac
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
CC=${CC:-cc}
work=$(mktemp -d "${TMPDIR:-/tmp}/envcheck.XXXXXX") || { echo "envcheck: cannot make a temporary directory" >&2; exit 1; }
trap 'rm -rf "$work"' EXIT
trap 'rm -rf "$work"; exit 130' INT TERM
res=$work/results
fails=$work/failures
: > "$res"
: > "$fails"
t_start=$(date +%s)

# What each mode spends, in seconds and sizes.
if [ $mode = fast ]; then
  clock_s=1; fma_s=1; pairs_s=0.2; pairs_which=all; ping_rounds=20000
  cache_kib=65536; membw_mib=64; membw_s=0.4; jitter_s=3
  disk_mib=256; disk_s=0.5; disk_files=2000; net_max=3; net_bytes=16000000
else
  clock_s=4; fma_s=4; pairs_s=1; pairs_which=all; ping_rounds=200000
  cache_kib=524288; membw_mib=512; membw_s=2; jitter_s=10
  disk_mib=2048; disk_s=3; disk_files=20000; net_max=15; net_bytes=100000000
fi

# ---------------------------------------------------------------- reporting
put() {   # put KEY VALUE: record a result and show it
  printf '%s=%s\n' "$1" "$2" >> "$res"
  printf '  %-34s %s\n' "$1" "$2"
}
fail() {   # fail PART WHY: something that could not be done here
  printf '%s\t%s\n' "$1" "$2" >> "$fails"
  printf '  %-34s %s\n' "!! $1" "$2"
}
get() { awk -v k="$1" 'index($0, k "=") == 1 { print substr($0, length(k) + 2); exit }' "$res"; }
section() { printf '\n== %s\n' "$1"; }
num() { printf '%s\n' "$1" | sed -n 's/^[^0-9]*\([0-9][0-9.]*\).*/\1/p'; }
# plausible KEY LO HI: the first number of a result lies in [LO, HI]
plausible() {
  v=$(num "$(get "$1")")
  [ -z "$v" ] && return 0
  if ! awk -v v="$v" -v lo="$2" -v hi="$3" 'BEGIN { exit !(v >= lo && v <= hi) }'; then
    fail "$1" "implausible value $v (expected $2 to $3): the measurement is wrong here"
  fi
}
have() { command -v "$1" > /dev/null 2>&1; }
if have timeout; then tmo=timeout; else tmo=""; fi

# probe SECONDS NAME ARGS...: run a command of the probe program and record
# what it prints
probe() {
  limit=$1; name=$2; shift 2
  if [ ! -x "$work/probe" ]; then fail "$name" "not run: the probe program did not compile"; return; fi
  if [ -n "$tmo" ]; then $tmo "$limit" "$work/probe" "$@" > "$work/p.out" 2> "$work/p.err"; rc=$?
  else "$work/probe" "$@" > "$work/p.out" 2> "$work/p.err"; rc=$?; fi
  while IFS= read -r line; do
    case "$line" in
      error=*|unsupported=*) ;;
      *=*) put "${line%%=*}" "${line#*=}" ;;
    esac
  done < "$work/p.out"
  case $rc in
    0) ;;
    124) fail "$name" "timed out after $limit s" ;;
    3) fail "$name" "unsupported here: $(sed -n 's/^unsupported=//p' "$work/p.out")" ;;
    *) fail "$name" "exit status $rc: $(sed -n 's/^error=//p' "$work/p.out" | head -1)$(head -1 "$work/p.err")" ;;
  esac
}

cat <<EOF
envcheck ($mode mode) on $(uname -n 2>/dev/null || echo ?), $(date -u '+%Y-%m-%d %H:%M UTC')
EOF

# ---------------------------------------------------------------- build
if ! have "$CC"; then
  fail build "no C compiler ($CC): every measurement is left out; set CC or install one"
elif ! "$CC" -std=gnu99 -O2 -pthread -o "$work/probe" scripts/envcheck.c -lm > "$work/cc.log" 2>&1; then
  fail build "$CC cannot compile scripts/envcheck.c: $(grep -m1 -i error "$work/cc.log")"
fi

# ---------------------------------------------------------------- system
section "System"
s0=$(date +%s)
put os.kernel "$(uname -srm)"
if [ -r /etc/os-release ]; then put os.release "$(. /etc/os-release; echo "${PRETTY_NAME:-$NAME}")"; fi
[ -r /proc/1/comm ] && put os.init "$(cat /proc/1/comm) (PID 1)"
up=$(awk '{ printf "%.0f", $1 }' /proc/uptime 2>/dev/null)
[ -n "$up" ] && put os.uptime "$((up / 3600)) h $((up % 3600 / 60)) min (since $(date -u -d "@$(( $(date +%s) - up ))" '+%H:%M UTC' 2>/dev/null))"
virt=""
if have systemd-detect-virt; then
  virt="$(systemd-detect-virt --vm 2>/dev/null) (VM), $(systemd-detect-virt --container 2>/dev/null) (container)"
fi
[ -r /sys/class/dmi/id/sys_vendor ] && virt="$virt; DMI $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
case "$(cat /proc/cmdline 2>/dev/null)" in *firecracker*) virt="$virt; Firecracker (kernel command line)" ;; esac
case "$(uname -r)" in *[Mm]icrosoft*|*WSL*) virt="$virt; WSL2" ;; esac
[ -n "$virt" ] && put os.virtualization "${virt#; }"
cmd=$(tr ' ' '\n' < /proc/cmdline 2>/dev/null | grep -E '^(ipv6\.disable|nosmt|mitigations|isolcpus|nohz_full)=' | tr '\n' ' ')
[ -n "$cmd" ] && put os.kernel_options "$cmd"
env_list=""
for v in CLAUDE_CODE_REMOTE CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE IS_SANDBOX CI GITHUB_ACTIONS CODESPACES; do
  eval "val=\${$v:-}"
  [ -n "$val" ] && env_list="$env_list $v=$val"
done
env_list=${env_list# }
put os.environment_markers "${env_list:-none}"
put os.proxy "$( [ -n "${HTTPS_PROXY:-${https_proxy:-}}" ] && echo "HTTPS_PROXY is set" || echo "none")"

put mem.total "$(awk '/^MemTotal/ { printf "%.1f GiB", $2 / 1048576 }' /proc/meminfo)"
put mem.swap "$(awk '/^SwapTotal/ { if ($2 == 0) print "none"; else printf "%.1f GiB", $2 / 1048576 }' /proc/meminfo)"
put mem.overcommit "$(cat /proc/sys/vm/overcommit_memory 2>/dev/null) (0 heuristic, 1 always, 2 never)"
# the memory limit of this process's cgroup, v2 or v1, and of the groups above it
lim=""
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
  p=$(sed -n 's/^0:://p' /proc/self/cgroup)
  while :; do
    f=/sys/fs/cgroup$p/memory.max
    [ -r "$f" ] && [ "$(cat "$f")" != max ] && lim="$lim $(awk '{ printf "%.2f GiB", $1 / 1073741824 }' "$f") at ${p:-/} (v2);"
    [ -z "$p" ] || [ "$p" = / ] && break
    p=${p%/*}
  done
fi
p=$(sed -n 's/^[0-9]*:memory:\(.*\)/\1/p' /proc/self/cgroup)
if [ -n "$p" ] && [ -d /sys/fs/cgroup/memory ]; then
  while :; do
    f=/sys/fs/cgroup/memory$p/memory.limit_in_bytes
    if [ -r "$f" ]; then
      b=$(cat "$f")
      [ "${#b}" -lt 19 ] && lim="$lim $(awk -v b="$b" 'BEGIN { printf "%.2f GiB", b / 1073741824 }') at ${p:-/} (v1);"
    fi
    [ -z "$p" ] || [ "$p" = / ] && break
    p=${p%/*}
  done
fi
lim=$(printf '%s' "$lim" | sed 's/^ //; s/;$//')
put mem.cgroup_limit "${lim:-none}"
cpu_lim=""
[ -r /sys/fs/cgroup/cpu.max ] && cpu_lim="$(cat /sys/fs/cgroup/cpu.max) (v2)"
q=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null)
[ -n "$q" ] && [ "$q" != -1 ] && cpu_lim="$cpu_lim quota $q per $(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us) us (v1)"
put cpu.cgroup_limit "${cpu_lim:-none}"
[ -d /sys/bus/virtio/drivers/virtio_balloon ] && ls /sys/bus/virtio/drivers/virtio_balloon | grep -q virtio && put mem.balloon "a virtio balloon: the host can take memory back"
put ulimit.virtual "$(ulimit -v)"

space() {   # space NAME DIR
  [ -d "$2" ] || return 0
  v=$(df -hT "$2" 2>/dev/null | awk 'NR == 2 { printf "%s free of %s (%s on %s)", $5, $3, $2, $1 }')
  [ -n "$v" ] && put "disk.space.$1" "$v, $2"
}
space repository "$root"
space tmp "${TMPDIR:-/tmp}"
space home "$HOME"
space shm /dev/shm
[ -w "$root" ] || put disk.note "the repository is not writable by $(id -un): building here needs that"
put disk.root_mount "$(awk '$2 == "/" { print $3 " " $4 }' /proc/mounts | head -1)"
printf 'time.system=%s s\n' "$(( $(date +%s) - s0 ))" >> "$res"

# ---------------------------------------------------------------- cpu identity
section "CPU identity and instruction set"
s0=$(date +%s)
put cpu.count "$(getconf _NPROCESSORS_ONLN) online, $(nproc 2>/dev/null) usable by this process"
put cpu.model_name "$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1)"
mc=$(sed -n 's/^microcode[[:space:]]*: //p' /proc/cpuinfo | head -1)
[ -n "$mc" ] && put cpu.microcode "$mc"
case "$(uname -m)" in
  x86_64)
    probe 10 cpuid cpuid
    probe 10 isa isa
    [ "$(get cpu.uarch)" = unknown ] && fail cpu.uarch "family $(get cpu.family), model $(get cpu.model_hex), stepping $(get cpu.stepping) is not in the table: add a row to uarchs[] in scripts/envcheck.c"
    # What the instructions that run say, which a hypervisor cannot hide.
    runs() { case "$(get "isa.$1")" in yes*|MISMATCH:\ runs*) return 0 ;; *) return 1 ;; esac; }
    by=""
    if [ "$(get cpu.vendor)" = GenuineIntel ]; then
      if runs amx-fp16; then by="Granite Rapids or newer"
      elif runs amx-tile || runs avx512fp16; then by="Sapphire Rapids or newer"
      elif runs avx512bf16 && runs avx512vbmi2; then by="Sapphire Rapids or newer"
      elif runs avx512vbmi2 && runs gfni; then by="Ice Lake or newer (Ice Lake-SP if it has no AVX-512 BF16, AMX)"
      elif runs avx512bf16; then by="Cooper Lake"
      elif runs avx512vnni; then by="Cascade Lake"
      elif runs avx512f; then by="Skylake-SP"
      elif runs avx2; then by="Haswell or newer (no AVX-512)"
      fi
    elif [ "$(get cpu.vendor)" = AuthenticAMD ]; then
      if runs avx512vp2intersect 2>/dev/null; then by="Zen 5"
      elif runs avx512f; then by="Zen 4 or newer"
      elif runs vaes; then by="Zen 3"
      elif runs avx2; then by="Zen or Zen 2"
      fi
    fi
    [ -n "$by" ] && put cpu.uarch_by_instructions "$by"
    hidden=$(sed -n 's/^isa\.\([^=]*\)=MISMATCH: runs.*/\1/p' "$res" | tr '\n' ' ' | sed 's/ $//')
    if [ -n "$hidden" ]; then
      put cpu.hidden_by_cpuid "${hidden}: these run although cpuid does not claim them, so the hypervisor presents a CPU model older than the hardware"
    fi
    faults=$(sed -n 's/^isa\.\([^=]*\)=MISMATCH: claimed.*/\1/p' "$res" | tr '\n' ' ' | sed 's/ $//')
    [ -n "$faults" ] && fail isa "claimed by cpuid but faulting: $faults"
    ;;
  *)
    put cpu.info "$(grep -m4 -E '^(CPU implementer|CPU part|CPU variant|Features)' /proc/cpuinfo | tr '\n' ';')"
    fail cpu "no cpuid and instruction tests for $(uname -m): add them to scripts/envcheck.c"
    ;;
esac
# the topology Linux sees
sib=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list 2>/dev/null | sort -u | tr '\n' ' ')
[ -n "$sib" ] && put topo.linux_thread_siblings "$sib"
pk=$(cat /sys/devices/system/cpu/cpu*/topology/physical_package_id 2>/dev/null | sort -u | wc -l)
put topo.linux_packages "$pk"
printf 'time.cpu_identity=%s s\n' "$(( $(date +%s) - s0 ))" >> "$res"

# ---------------------------------------------------------------- topology
section "Cores, caches and neighbours"
s0=$(date +%s)
read -r st0 tot0 <<EOF
$(awk '/^cpu / { t = 0; for (i = 2; i <= 9; i++) t += $i; print $9, t }' /proc/stat)
EOF
if [ "$(uname -m)" = x86_64 ]; then
  probe 60 pairs pairs "$pairs_s" "$pairs_which"
  plausible pairs.lowest_ratio 0.2 1.5
  probe 60 pingpong pingpong "$ping_rounds" "$pairs_which"
fi
probe 60 cachecurve cachecurve "$cache_kib"
# the sizes the latency shows: L1 always, L2 and L3 with --slow
if [ $mode = fast ]; then probe 30 cachesizes cachesizes l1 1024
else probe 120 cachesizes cachesizes all "$cache_kib"; fi
kib() {   # kib VALUE: the size at the head of a result, in KiB
  printf '%s\n' "$1" | awk '{ v = $1; u = $2; if (u ~ /^MiB/) v *= 1024; if (v > 0) printf "%d\n", v }'
}
for lv in L1d L1i L2 L3; do
  m=$(kib "$(get cachesize.$lv)"); c=$(kib "$(get cache.$lv)")
  [ -n "$m" ] && [ -n "$c" ] || continue
  # an exact size (L1) must agree; an effective one within a factor of 1.5
  case $lv in L1?) exact=1 ;; *) exact=0 ;; esac
  if [ $exact = 1 ] && [ "$m" != "$c" ]; then
    put cache.note.$lv "measured $m KiB, cpuid says $c KiB: the hypervisor presents another CPU's caches"
  elif [ $exact = 0 ] && awk -v m="$m" -v c="$c" 'BEGIN { exit !(m * 1.5 < c || m > c * 1.5) }'; then
    put cache.note.$lv "measured about $m KiB, cpuid says $c KiB$( [ $lv = L3 ] && echo ': this VM gets part of a shared L3')"
  fi
done
probe 60 jitter jitter "$jitter_s"
printf 'time.topology=%s s\n' "$(( $(date +%s) - s0 ))" >> "$res"

# ---------------------------------------------------------------- speed
section "Speed"
s0=$(date +%s)
if [ "$(uname -m)" = x86_64 ]; then
  probe 120 clock clock "$clock_s"
  plausible clock.scalar.one_core 0.3 8
  probe 60 fma fma "$fma_s"
fi
# arrays far larger than the caches: each at least twice the L3 that cpuid
# reports (arrays of 64 MiB measured the L3 of an Emerald Rapids, 260 MiB),
# the three within a quarter of the memory this process may use
l3=$(kib "$(get cache.L3)")
if [ -n "$l3" ]; then
  mem_mib=$(printf '%s; %s\n' "$(get mem.total)" "$(get mem.cgroup_limit)" |
    awk -v RS=';' '$2 == "GiB" { m = $1 * 1024; if (!min || m < min) min = m } END { print int(min) }')
  membw_mib=$(awk -v m="$membw_mib" -v l="$l3" -v r="$mem_mib" \
    'BEGIN { w = int((2 * l + 1023) / 1024); if (r > 0 && w * 12 > r) w = int(r / 12); print (w > m ? w : m) }')
fi
probe 120 membw membw "$membw_mib" "$membw_s"
plausible membw.triad.one_thread 0.3 500
ddir=${ENVCHECK_DIR:-$work}
dfs=$(df -T "$ddir" 2>/dev/null | awk 'NR == 2 { print $2 }')
put disk.tested_in "$ddir ($dfs)"
case "$dfs" in tmpfs|ramfs) put disk.note "$ddir is $dfs, memory: the figures below are of RAM, not of a disk (set ENVCHECK_DIR)" ;; esac
avail=$(df -Pk "$ddir" 2>/dev/null | awk 'NR == 2 { print int($4 / 1024) }')
if [ -n "$avail" ] && [ "$avail" -lt $((disk_mib * 2)) ]; then
  fail disk "only $avail MiB free in $ddir: the disk test needs $((disk_mib * 2))"
else
  probe 180 disk disk "$ddir" "$disk_mib" "$disk_s" "$disk_files"
  plausible disk.sequential_write 1 100000
fi
# network: the start of a few files from the places this repository fetches
# from; a source that does not answer is reported, not a failure
if have curl; then
  net_one() {
    out=$(curl -sS -L -o /dev/null --max-time "$net_max" -r "0-$((net_bytes - 1))" \
          -w '%{http_code} %{size_download} %{time_starttransfer} %{time_total}' "$2" 2>/dev/null)
    set -- "$1" $out
    if [ $# -ge 5 ] && [ "$3" -gt 0 ] 2>/dev/null; then
      put "net.$1" "$(awk -v b="$3" -v f="$4" -v t="$5" -v c="$2" 'BEGIN { printf "%.1f MB/s, first byte after %.0f ms (%.1f MB in %.1f s, HTTP %s)", b / (t - f > 0 ? t - f : t) / 1e6, f * 1000, b / 1e6, t, c }')"
    else
      put "net.$1" "no answer within $net_max s"
    fi
  }
  net_one github https://github.com/MLton/mlton/releases/download/on-20241230-release/mlton-20241230-1.amd64-linux.ubuntu-24.04_glibc2.39.tgz
  net_one pypi https://files.pythonhosted.org/packages/source/n/numpy/numpy-2.1.0.tar.gz
  net_one smlnj https://smlnj.cs.uchicago.edu/dist/working/110.99.9/boot.amd64-unix.tgz
  net_one ubuntu https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso
  grep -q '^net\..*MB/s' "$res" || put net.note "no source answered: no network, or none of these hosts is allowed"
else
  put net.note "curl is not installed: the network is not measured"
fi
printf 'time.speed=%s s\n' "$(( $(date +%s) - s0 ))" >> "$res"

# ---------------------------------------------------------------- where
# Which cloud and region, as far as the machine can tell: DMI, the cloud
# metadata endpoints, the network the traffic leaves from (ipinfo.io; not
# with ENVCHECK_NO_EGRESS=1), and what the CPU model and clock say. In a VM
# nested in another, or behind a proxy, each is only a clue: the report
# ends in a guess that says so.
section "Where it runs"
s0=$(date +%s)
dmi=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
put where.dmi_vendor "${dmi:-none (no DMI: a microVM, or nested)}"
tsc=$(sed -n 's/^cpu MHz[[:space:]]*: //p' /proc/cpuinfo | head -1)
dtsc=$(dmesg 2>/dev/null | sed -n 's/.*tsc: Detected \([0-9.]*\) MHz.*/\1/p' | head -1)
put where.tsc "${dtsc:-$tsc} MHz: the nominal clock the VM is given, which a VM moved to other hardware keeps"
provider=""
if have curl; then
  md() {   # md NAME URL HEADER: what a metadata endpoint answers
    c=$(curl -sS -m 2 -o /dev/null -w '%{http_code}' -H "$3" "$2" 2>/dev/null)
    case "$c" in 200) echo "$1: answers" ;; 000|"") echo "$1: no answer" ;; *) echo "$1: HTTP $c" ;; esac
  }
  put where.metadata "$(md aws http://169.254.169.254/latest/meta-data/ 'X-a: b'); $(md azure 'http://169.254.169.254/metadata/instance?api-version=2021-02-01' 'Metadata: true'); $(md gcp http://metadata.google.internal/computeMetadata/v1/ 'Metadata-Flavor: Google')"
  case "$(get where.metadata)" in
    *"aws: answers"*) provider="Amazon Web Services (metadata)" ;;
    *"azure: answers"*) provider="Microsoft Azure (metadata)" ;;
    *"gcp: answers"*) provider="Google Cloud (metadata)" ;;
  esac
  if [ "${ENVCHECK_NO_EGRESS:-0}" = 1 ]; then
    put where.egress "not asked (ENVCHECK_NO_EGRESS=1)"
  else
    # three times: the egress address rotates, and one address can be
    # placed in another city; the region is taken from the commonest city
    : > "$work/egress"
    f() { printf '%s' "$j" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }
    for i in 1 2 3; do
      j=$(curl -sS -m 5 https://ipinfo.io/json 2>/dev/null)
      [ -n "$(f ip)" ] && printf '%s\t%s\t%s\t%s\t%s\n' "$(f ip)" "$(f org)" "$(f city)" "$(f region)" "$(f country)" >> "$work/egress"
    done
    if [ -s "$work/egress" ]; then
      IFS="$(printf '\t')" read -r ip org city region country <<EOF2
$(cut -f 3 "$work/egress" | sort | uniq -c | sort -rn | head -1 | sed 's/^ *[0-9]* //' | while read -r c; do grep -m1 "$(printf '\t')$c$(printf '\t')" "$work/egress"; done)
EOF2
      put where.egress "$ip, $org, $city, $region, $country (where the traffic leaves: the proxy's, if there is one; cities seen: $(cut -f 3 "$work/egress" | sort | uniq -c | awk '{ c = $1; $1 = ""; printf "%s%s x%d", (NR > 1 ? ", " : ""), substr($0, 2), c }'))"
    else
      put where.egress "ipinfo.io did not answer"
    fi
    # behind a proxy, a connection that bypasses it, where one is allowed:
    # the machine's own egress, which the proxy's can be far from
    if [ -n "${HTTPS_PROXY:-${https_proxy:-}}" ]; then
      j=$(curl -sS -m 5 --noproxy '*' https://ipinfo.io/json 2>/dev/null)
      dip=$(f ip)
      if [ -n "$dip" ]; then
        dorg=$(f org); dcity=$(f city)
        put where.egress_direct "$dip, $dorg, $dcity, $(f region), $(f country) (a connection that bypasses the proxy)"
      else
        put where.egress_direct "none: only the proxy reaches the internet"
      fi
    fi
    # Google Cloud and AWS publish the region of each of their address
    # ranges, which is exact where a database's city is not; an address
    # outside them (a proxy's own block) is no evidence of the region
    if [ -n "${ip:-}${dip:-}" ]; then
      curl -sS -m 10 -o "$work/gcp.json" https://www.gstatic.com/ipranges/cloud.json 2>/dev/null
      curl -sS -m 10 -o "$work/aws.json" https://ip-ranges.amazonaws.com/ip-ranges.json 2>/dev/null
      inrange() {   # inrange FILE IP KEY: "prefix region" of the longest prefix holding IP
        [ -s "$1" ] || return 0
        awk -v ip="$2" -v kp="$3:" '
          function num(a,   q) { split(a, q, "."); return ((q[1] * 256 + q[2]) * 256 + q[3]) * 256 + q[4] }
          BEGIN { x = num(ip); best = -1 }
          { gsub(/[",]/, "") }
          /\{/ { hit = 0 }
          $1 == kp { split($2, c, "/"); n = c[2] + 0; hit = x - x % 2 ^ (32 - n) == num(c[1]); pfx = $2 }
          ($1 == "scope:" || $1 == "region:") && hit && n > best { best = n; r = pfx " " $2 }
          END { if (best >= 0) print r }' "$1"
      }
      rng() {   # rng IP: the provider and region whose published ranges hold IP
        case "$1" in *.*.*.*) ;; *) echo "not looked up (not IPv4)"; return ;; esac
        r=$(inrange "$work/gcp.json" "$1" ipv4Prefix)
        if [ -n "$r" ]; then echo "Google Cloud, ${r#* } ($1 in ${r%% *})"; return; fi
        r=$(inrange "$work/aws.json" "$1" ip_prefix)
        if [ -n "$r" ]; then echo "Amazon Web Services, ${r#* } ($1 in ${r%% *})"; return; fi
        echo "$1 is in neither Google Cloud's nor AWS's published ranges"
      }
      [ -n "${dip:-}" ] && put where.range_direct "$(rng "$dip")"
      [ -n "${ip:-}" ] && put where.range_egress "$(rng "$ip")"
    fi
  fi
fi
case "$dmi" in
  Google*) provider=${provider:-"Google Cloud (DMI)"} ;;
  Amazon*) provider=${provider:-"Amazon Web Services (DMI)"} ;;
  Microsoft*) provider=${provider:-"Microsoft Azure or Hyper-V (DMI)"} ;;
esac
# the published ranges name the provider and the region: the direct
# egress's first, then the proxy's
reg=""
for v in "$(get where.range_direct)" "$(get where.range_egress)"; do
  case "$v" in "Google Cloud, "*|"Amazon Web Services, "*) ;; *) continue ;; esac
  case "$provider" in ""|"${v%%,*} "*) ;; *) continue ;; esac
  provider=${provider:-"${v%%,*} (its published address ranges)"}
  reg=${v#*, }; reg=${reg%% *}
  case "$reg" in GLOBAL|global) reg="" ;; esac   # AWS's edge, in no region
  break
done
# else the owner of the egress network, the direct one first
ecity=""
if [ -z "$provider" ]; then
  for oc in "${dorg:-}|${dcity:-}" "${org:-}|${city:-}"; do
    case "${oc%%|*}" in
      *Google*) provider="Google Cloud (the egress network)" ;;
      *Amazon*|*AWS*) provider="Amazon Web Services (the egress network)" ;;
      *Microsoft*) provider="Microsoft Azure (the egress network)" ;;
      *Oracle*) provider="Oracle Cloud (the egress network)" ;;
      *) continue ;;
    esac
    ecity=${oc#*|}; break
  done
fi
# the region a provider has in the egress city (a small table: add to it)
[ -z "$reg" ] && case "${provider%% (*}/${ecity:-${dcity:-${city:-}}}" in
  "Google Cloud/Columbus") reg=us-east5 ;;
  "Google Cloud/Council Bluffs") reg=us-central1 ;;
  "Google Cloud/The Dalles") reg=us-west1 ;;
  "Google Cloud/Ashburn") reg=us-east4 ;;
  "Google Cloud/Moncks Corner") reg=us-east1 ;;
  "Google Cloud/Los Angeles") reg=us-west2 ;;
  "Google Cloud/Salt Lake City") reg=us-west3 ;;
  "Google Cloud/Las Vegas") reg=us-west4 ;;
  "Google Cloud/Dallas") reg=us-south1 ;;
  "Amazon Web Services/Ashburn") reg=us-east-1 ;;
  "Amazon Web Services/Columbus"|"Amazon Web Services/Dublin") reg=us-east-2 ;;
  "Amazon Web Services/Boardman") reg=us-west-2 ;;
esac
guess="${provider:-an unknown provider}${reg:+, region $reg}"
# a CPU model older than the instructions that run: the hypervisor keeps a
# model the VM started with (Google Cloud's N2 does, on Ice Lake hosts that
# replaced Cascade Lake ones) or applies a CPU template
if [ -n "$(get cpu.hidden_by_cpuid)" ]; then
  guess="$guess; the hardware ($(get cpu.uarch_by_instructions | cut -d' ' -f1-2)) is newer than the CPU model presented ($(get cpu.uarch)), with the nominal clock of that model (${dtsc:-$tsc} MHz)"
fi
case "$(get os.virtualization)" in
  *Firecracker*) guess="$guess; a Firecracker microVM, which on a public cloud runs nested in one of its VMs" ;;
esac
put where.guess "$guess"
printf 'time.where=%s s\n' "$(( $(date +%s) - s0 ))" >> "$res"

read -r st1 tot1 <<EOF
$(awk '/^cpu / { t = 0; for (i = 2; i <= 9; i++) t += $i; print $9, t }' /proc/stat)
EOF
[ "$tot1" -gt "$tot0" ] && put cpu.steal_during_run "$(awk -v s="$((st1 - st0))" -v t="$((tot1 - tot0))" 'BEGIN { printf "%.2f%% of CPU time", 100 * s / t }')"

# ---------------------------------------------------------------- summary
section "Summary"
elapsed=$(( $(date +%s) - t_start ))
put envcheck.mode "$mode, $elapsed s"
if [ $mode = fast ] && [ $elapsed -gt 60 ]; then
  fail envcheck.time "the fast mode took $elapsed s, more than a minute: lower its budgets at the head of scripts/envcheck.sh"
fi
# The fingerprint names a kind of machine; each entry of cloud/ENVIRONMENT.md
# has a line "Fingerprint: `...`" for the kind it describes.
kflavour=$(uname -r | sed 's/^[0-9][0-9.]*[-+]*//')
# from cpuid, or from /proc/cpuinfo when the probe could not run
ci() { sed -n "s/^$1[[:space:]]*: //p" /proc/cpuinfo | head -1; }
fv=$(get cpu.vendor); ff=$(get cpu.family); fm=$(get cpu.model); fs=$(get cpu.stepping); fh=$(get cpu.hypervisor)
[ -n "$fv" ] || { fv=$(ci vendor_id); ff=$(ci 'cpu family'); fm=$(ci model); fs=$(ci stepping); }
[ -n "$fv" ] || { fv=$(ci 'CPU implementer'); ff=$(ci 'CPU architecture'); fm=$(ci 'CPU part'); fs=$(ci 'CPU variant'); }
if [ -z "$fh" ]; then   # systemd's name for it, as cpuid's signature
  case "$(have systemd-detect-virt && systemd-detect-virt --vm 2>/dev/null)" in
    kvm) fh=KVMKVMKVM ;; microsoft) fh="Microsoft Hv" ;; vmware) fh=VMwareVMware ;;
    xen) fh=XenVMMXenVMM ;; none|"") fh=none ;; *) fh=$(systemd-detect-virt --vm) ;;
  esac
fi
# hardware newer than the model presented (instructions run that cpuid does
# not claim) is another kind of machine behind the same cpuid: name it
hw=""
[ -n "$(get cpu.hidden_by_cpuid)" ] && hw=$(get cpu.uarch_by_instructions | sed 's/ or newer.*//; s/ (.*//')
fp="$fv $ff/$fm/$fs${hw:+ on $hw}, $(getconf _NPROCESSORS_ONLN) CPUs, $(get mem.total), ${fh:-none}, kernel ${kflavour:-$(uname -r)}"
put envcheck.fingerprint "$fp"
if grep -F "Fingerprint" cloud/ENVIRONMENT.md 2>/dev/null | grep -qF "\`$fp\`"; then
  put envcheck.known "yes: cloud/ENVIRONMENT.md describes this kind of machine"
else
  put envcheck.known "no: cloud/ENVIRONMENT.md has no entry with this fingerprint"
  if [ -n "${CLAUDE_CODE_REMOTE:-}" ]; then
    echo "  A new kind of machine: add an entry to cloud/ENVIRONMENT.md (--markdown prints one to start from)."
  fi
fi

if [ -n "$json" ]; then
  awk -F= 'BEGIN { print "{" } { k = $1; v = substr($0, length(k) + 2); gsub(/\\/, "\\\\", v); gsub(/"/, "\\\"", v); gsub(/\t/, " ", v)
                    printf "%s  \"%s\": \"%s\"", (NR > 1 ? ",\n" : ""), k, v } END { print "\n}" }' "$res" > "$json" &&
    echo "  results written to $json"
fi

if [ $markdown = 1 ]; then
  g() { get "$1"; }
  ms() { v=$(get "cachesize.$1" | cut -d' ' -f1-2); echo "${v:-not measured (--slow)}"; }
  hid() { v=$(get cpu.hidden_by_cpuid | cut -d: -f1); echo "${v:-none}"; }
  nz() { v=$(get "$1" | sed "${2:-}"); echo "${v:-none}"; }
  cat <<EOF

--- an entry for cloud/ENVIRONMENT.md (check it; nothing was written) ---

## N. $( [ -n "${CLAUDE_CODE_REMOTE:-}" ] && echo "Claude Code on the web" || echo "SERVICE"), $(date -u +%Y-%m-%d)

* **Fingerprint:** \`$fp\`
* **Hypervisor:** $(g os.virtualization); cpuid hypervisor $(g cpu.hypervisor). Kernel $(uname -r); init $(g os.init).
* **CPU:** $(g cpu.model_name); cpuid says $(g cpu.uarch) (family $(g cpu.family), model $(g cpu.model_hex), stepping $(g cpu.stepping)), the instructions that run say $(g cpu.uarch_by_instructions). $(g cpu.count). Caches as cpuid says: L1d $(g cache.L1d | cut -d, -f1), L2 $(g cache.L2 | cut -d, -f1), L3 $(g cache.L3 | cut -d, -f1); as measured: L1d $(ms L1d), L2 $(ms L2), L3 $(ms L3). Hidden by cpuid: $(hid).
* **Clock:** $(g clock.scalar.one_core) on one core, $(g clock.scalar.all_cores_each) with all busy; 512-bit FMA $(g fma.512.one_core).
* **Cores and neighbours:** pairs of vCPUs always on one core: $(g pairs.always_sharing_a_core), sometimes: $(g pairs.sometimes_sharing_a_core); cache line between CPUs $(g pingpong.summary); steal $(g jitter.steal); pauses over 1 ms $(g jitter.pauses_over_1ms), longest $(g jitter.longest_pause).
* **Memory:** $(g mem.total), swap $(g mem.swap), cgroup limit $(g mem.cgroup_limit); triad $(g membw.triad.one_thread) on one thread, $(g membw.triad.all_threads).
* **Disk:** $(g disk.space.repository); sequential write $(g disk.sequential_write), read $(g disk.sequential_read), cold $(g disk.sequential_read_cold); random 4 KiB read $(g disk.random_4k_read.1_thread); fdatasync $(g disk.fdatasync_4k).
* **Where:** $(g where.guess). Egress: $(g where.egress | sed 's/ (where.*//'); direct: $(nz where.egress_direct 's/ (a connection.*//'); published ranges: $(nz where.range_direct) (direct), $(nz where.range_egress) (egress); metadata: $(g where.metadata); DMI: $(g where.dmi_vendor).
* **Network:** proxy: $(g os.proxy); GitHub $(g net.github | cut -d, -f1), PyPI $(g net.pypi | cut -d, -f1), Ubuntu $(g net.ubuntu | cut -d, -f1).
EOF
fi

# ---------------------------------------------------------------- problems
status=0
if [ -s "$fails" ]; then
  status=2
  cat <<EOF

== envcheck could not do everything here
EOF
  while IFS="$(printf '\t')" read -r part why; do printf '  %s: %s\n' "$part" "$why"; done < "$fails"
  cat <<EOF

  To the agent running this: make scripts/envcheck.sh and scripts/envcheck.c
  work in this environment (docs/envcheck.md says how each part works and
  what it assumes), run them again, and commit the fix, with an entry for
  the machine in cloud/ENVIRONMENT.md if it is a new kind.
EOF
fi

# ---------------------------------------------------------------- commit test
# Last, and only when asked: it can kill this shell's processes or restart
# the container, so everything above is reported before it starts.
if [ $commit = 1 ]; then
  section "Committable memory (--commit-test)"
  total_mib=$(awk '/^MemTotal/ { m = $2 } /^SwapTotal/ { s = $2 } END { print int((m + s) / 1024) + 1024 }' /proc/meminfo)
  echo "  allocating 256 MiB at a time, up to $total_mib MiB, until the kernel stops it;"
  echo "  if the session's processes are killed or the container restarts, that was the limit."
  if [ -x "$work/probe" ]; then
    "$work/probe" commit 256 "$total_mib" "$work/commit.progress" > "$work/commit.out" 2>&1
    rc=$?
    reached=$(cat "$work/commit.progress" 2>/dev/null || echo 0)
    if [ $rc -ge 128 ]; then
      put mem.committable "$(awk -v m="$reached" 'BEGIN { printf "%.2f GiB", m / 1024 }') touched, then killed by signal $((rc - 128)) (9 is the OOM killer)"
    else
      put mem.committable "$(sed -n 's/^commit\.//p' "$work/commit.out" | head -1) (not killed; reached $reached MiB)"
    fi
    dmesg 2>/dev/null | grep -i 'out of memory' | tail -1 | sed 's/^/  kernel: /'
  else
    fail commit-test "not run: the probe program did not compile"
    status=2
  fi
else
  printf '\nNot run: the committable-memory test (scripts/envcheck.sh --commit-test), which\nallocates memory until the kernel stops it and can kill this session'"'"'s processes\nor restart the container. Run it on purpose, last.\n'
fi
exit $status
