# Cloud environments

Machines that Rune has been built and tested on in cloud coding environments.

**For agents:** this file only matters when you run in a cloud coding
environment (for Claude Code on the web: `CLAUDE_CODE_REMOTE=true`). If you
do, run `make envcheck` (docs/envcheck.md): it compares the machine's
fingerprint with the `Fingerprint:` lines below. If it is a kind of machine
not listed yet (another CPU generation, core count, memory size, OS,
hypervisor or cloud service), add a new entry at the end;
`make envcheck ENVCHECK=--markdown` prints one to start from. Running
locally, leave this file alone.

## 1. Claude Code on the web (Anthropic cloud), 2026-09-25

* **Fingerprint:** `GenuineIntel 6/85/7 on Ice Lake, 4 CPUs, 15.7 GiB, KVMKVMKVM, kernel fc-v37`
* **Where** (`make envcheck`): **Google Cloud, region `us-central1`
  (Council Bluffs, Iowa), a Firecracker microVM nested in an N2 VM on Ice
  Lake hosts.** A connection that bypasses the proxy leaves from
  34.59.45.162, in Google Cloud's published range 34.56.0.0/14 of
  `us-central1`. The proxy's addresses, of 160.79.106.0/24 (AS396982
  Google LLC, placed in Columbus, now and then in Chicago), are in none of
  Google Cloud's published ranges, so their city said nothing about the
  region: an earlier guess of `us-east5` rested on it. The CPU is an Ice
  Lake under a Cascade Lake model with Cascade Lake's 2.8 GHz nominal
  clock, as N2 VMs keep on newer hosts (the N2 VM is a guess). There is no
  DMI, and the metadata endpoints are blocked (AWS's and Azure's address
  answers 403, Google's name does not resolve), so nothing names the size
  of the VM that holds the microVM.
* **Service:** Claude Code on the web (claude.ai/code), Anthropic's managed
  cloud sessions. `CLAUDE_CODE_REMOTE=true`,
  `CLAUDE_CODE_ENTRYPOINT=remote`,
  `CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE=cloud_default`, `IS_SANDBOX=yes`.
  Setup: https://code.claude.com/docs/en/claude-code-on-the-web
* **Hypervisor:** Firecracker microVM on KVM (full virtualization); inside it
  a container (`systemd-detect-virt` says `docker`). Kernel
  `6.18.44-fc-v37`.
* **CPU:** Intel Xeon Scalable, presented as Cascade Lake (family 6, model
  85, stepping 7) but most likely **Ice Lake-SP**: ten extensions that
  `cpuid` does not claim run (SHA, GFNI, VAES, VPCLMULQDQ, RDPID, AVX-512
  IFMA, VBMI, VBMI2, BITALG, VPOPCNTDQ), which is what Ice Lake added, and
  none of what came after it (AVX-512 BF16 and FP16, AMX, SERIALIZE,
  MOVDIRI). The hypervisor presents a Cascade Lake CPU template, which hides
  features in `cpuid` but cannot stop them from running (`make envcheck`).
  The caches confirm it: `cpuid` gives Cascade Lake's (L1d 32 KiB, L2 1 MiB,
  L3 33 MiB 11-way), but the latency of a pointer chase (`make envcheck`)
  stays at 1.5 ns up to **48 KiB**, Ice Lake's L1d, and 1.5 ns is 5 cycles,
  Ice Lake's L1 latency (Cascade Lake has 4). L2 measures about 1 MiB
  effective (Ice Lake's is 1.25 MiB, filling gradually) at 4.3 ns; the L3
  about 3.5 to 5.5 MiB, varying between runs, at 25 to 27 ns: the VM gets
  a small, changing part of the host's L3, then memory at 150 to 250 ns.
  The brand string is masked (`Intel(R) Xeon(R) Processor @ 2.80GHz`,
  microcode `0x1`). Its 2.8 GHz, the nominal clock the VM is given (`tsc:
  Detected 2799.998 MHz`), is that of the Cascade Lake model, not of the
  hardware: Google Cloud's N2 keeps the CPU model and clock a VM started
  with on the Ice Lake hosts that followed Cascade Lake ones, which is what
  is seen here (see *Where*). N2's Ice Lake is the Xeon Platinum 8373C
  (2.6 GHz base, about 3.4 GHz on all cores), likely the part, but a guess.
  4 vCPUs (4 cores, 1 thread per core, 1 socket), which the host moves
  between its cores:
  now and then two of them share one core for a while.
* **Clock:** measured 3.2 GHz (3.17 to 3.29), on one core and on all four at
  once: turbo above the nominal 2.8 GHz, sustained. The VM shows only the
  nominal clock (no `cpufreq`, and `perf` cannot count cycles), so it was
  timed with a chain of dependent `add` instructions, one cycle each. The
  part's rated turbo is not visible.
* **Memory:** 15.7 GiB of RAM (`MemTotal` 16,481,980 kB), no swap (a
  `zram0` exists but is not set up). What the shell runs, builds and tests
  and background jobs together, is in the cgroup (v1)
  `/process_api/<id>/claude-code-bash`, whose `memory.limit_in_bytes` is
  14,345,912,320 bytes, **13.36 GiB**; the groups above it and `ulimit` set
  none. Tried: a program that touched 1 GiB at a time was killed by the
  cgroup's OOM killer (`CONSTRAINT_MEMCG`) at 13.33 GiB of its own. Without
  swap a process at the limit is killed, not slowed; the page cache counts
  too but is dropped first. The VM has a `virtio_balloon`, so the host can
  take memory back; `MemTotal` read the same every time. `make check`
  peaks at 2.6 GiB.
* **Restarts:** the container restarted three times in one session (at
  about 12:34, 13:19 and 14:38 UTC on 2026-09-25): processes and
  `/root/.gitconfig` are lost, the disk (packages, `~/.local/rune-hosts`,
  the build) is kept.
* **OS:** Ubuntu 24.04.4 LTS, x86_64. Runs as `root`.
* **Disk:** `/` is ext4 of which `df` reports 252 GB, but the session has a
  fixed allowance: about 30 GB free at the start. The repository, `/tmp`,
  `/root` (and `~/.local/rune-hosts`), `/usr/local` and `/opt` are all
  writable and all on it. `/dev/shm` is a 16 GB tmpfs (RAM). Everything is
  lost when the session ends; only what is pushed survives.
* **Disk speed** (measured 2026-09-25, `dd` and small C programs with
  `O_DIRECT`): `/dev/vda` is a virtio disk of 256 GiB (`mq-deadline`,
  readahead 8 MiB; it calls itself rotational but behaves like an SSD).
  Sequential write 549 MB/s; sequential read 2.0 GB/s of what was just
  written but 216 MB/s after `drop_caches`, so the host seems to keep
  recent writes near and to fetch older data from a slower tier (the first
  build after an idle pause, which drops the VM's cache, reads that way).
  Random 4 KiB: 19,700 reads or 19,900 writes a second on one thread,
  49,200 and 36,500 on four, median 44 to 74 us, now and then up to 57 ms.
  4 KiB write + `fdatasync`: 2,940 a second, 340 us on average (ext4
  without a journal), at most 44 ms. 20,000 files of 1 KiB: create 30,700,
  stat 611,000, read 156,000, delete 168,000 a second. Builds wait on the
  disk 0 to 3% of the time: it is not what limits them.
* **Tools present:** gcc 13.3, clang 18.1, GNU make 4.3, git 2.43,
  Python 3.11. Not present (see `cloud/SETUP.md`): libgmp-dev, gcc-multilib,
  dwarfdump, perf, MLton, SML/NJ, Poly/ML (`make hosts`), mingw-w64, the
  PowerPC cross tools, qemu. Windows programs cannot run (no Wine or WSL).
* **perf (the Linux command):** Ubuntu's perf 6.8 runs, linked as
  `/usr/local/bin/perf` (`cloud/SETUP.md`), but the VM has no hardware
  counters (no `cpu` device under `/sys/bus/event_source/devices`, only
  software, tracepoint, breakpoint, uprobe, msr and power). `perf stat`
  counts software events only (task-clock, context switches, page faults);
  cycles, instructions and cache misses are `<not supported>`. `perf
  record`, `report` and `annotate` work, sampling on a timer (cpu-clock)
  with call graphs, and name the SML functions and lines of a program of
  `runeopt` (`fib#230`, `q.sml:1`). No IPC, no cache-miss counts, no
  sampling on hardware events; a profile counts time the host took away too.
* **Network:** outbound HTTPS through an agent proxy (CA bundle
  `/root/.ccr/ca-bundle.crt`); GitHub through the session's own tools.
  PyPI and npm bypass the proxy (its `noProxy`). Measured 2026-09-25 with
  `curl`: 38 to 68 MB/s (300 to 550 Mbit/s) from releases.ubuntu.com,
  23 to 26 MB/s from a GitHub release, 23 to 25 MB/s from
  files.pythonhosted.org, 36 MB/s from registry.npmjs.org, 11 MB/s from
  smlnj.cs.uchicago.edu; mostly the source's limit, not the machine's.
  The first byte comes 0.3 to 0.6 s after the request through the proxy,
  70 to 100 ms without it, which dominates many small downloads (`apt`).
  Parts of the Ubuntu image past its first gigabyte came at only 1.4 to
  2.2 MB/s while its start and other sources stayed fast: the CDN's, not
  the proxy's (a whole-gigabyte download that ran into it seemed to hang).
  Upload speed not measured.
* **Cores and neighbours** (measured 2026-09-25):
  * The 4 vCPUs are 4 cores, not 2 cores of 2 threads, most of the time.
    Two vCPUs that saturate their execution units at once usually keep the
    throughput each has alone (512-bit FMA 4.4 to 5.2 G/s each, alone 4.9
    to 5.2; integer adds 8.0 to 11.2 G/s each, alone 8.6 to 11.2), and a
    cache line passes between two of them in 50 ns or more. But the host
    runs with SMT and places vCPUs freely: in some runs of `make envcheck`
    a pair kept only 0.63 to 0.71 of its throughput, or passed a cache
    line in 21 ns, which is two threads of one core, for a while.
  * The vCPUs are not pinned: the same pair measured 52 ns once and 158 ns
    another time, so the host moves them between its cores and, at about
    150 ns, probably between its sockets.
  * AVX-512 runs at about 2.5 GHz (2 FMAs a cycle, so the part has two FMA
    units), against 3.2 GHz for scalar code.
  * Neighbours are there but cost little: steal was 1.0% during 10 s with
    all 4 vCPUs busy (0.08% since boot); a vCPU stopped for over 1 ms 2 to
    4 times a second, at most 4 to 12 ms; the integer throughput of one
    vCPU varied by up to 25% between runs. Wall-clock times (`make perf`)
    are noisy here; `make perf-check` counts instructions and is not.
* **`make check`:** 13 min 9 s with the build in place, about 14.5 min from
  a clean tree (the build of the four hosts, the VM, the self-compile,
  `runedoc` and `runeopt` takes about 70 s). The longest steps:
  `check-cross` with `check-docs` 4.6 min, `test-basis` 2.4 min,
  `test-native` about 2 min, `test-opt` 1.5 min. It passes, with the 10
  INet6Sock socket checks skipped for want of IPv6 (the kernel has
  `ipv6.disable=1`).
* **Load of `make check`:** CPU busy 84% on average, and at 90% or more for
  60 to 80% of the time, so the 4 cores are what limits it; `test-basis`
  (96%), `check-positions` (95%) and `test-native` (92%) fill them longest.
  Memory peaks at 2.6 GiB of 15 during the build (MLton compiling the
  compiler, 1.3 GiB in one process) and stays under 1.4 GiB in the tests
  (`runevm` at most 470 MiB). I/O wait 0 to 3%, steal 0.4 to 0.6% (3% at
  most).

## 2. Claude Code on the web (Anthropic cloud), Emerald Rapids, 2026-09-25

* **Fingerprint:** `GenuineIntel 6/207/2, 4 CPUs, 15.7 GiB, KVMKVMKVM, kernel fc-v37`
* **Service:** as in entry 1, the same variables, except
  `CLAUDE_CODE_ENTRYPOINT=remote_desktop` (the session was started from the
  Claude desktop app). The same kind of VM on another CPU.
* **Where** (`make envcheck`): **Google Cloud, region `us-central1`, a
  Firecracker microVM nested in a VM of its C4 series (likely; see
  *CPU*).** A connection that bypasses the proxy (the hosts of its
  `noProxy`, such as PyPI) leaves from an external address of Compute
  Engine (`*.bc.googleusercontent.com`), a different one each time (three
  seen), each in a range that Google's `cloud.json` gives to
  `us-central1`. The proxy's address, of 160.79.106.0/24 and placed in
  Columbus (`us-east5`) as in entry 1, is in none of Google Cloud's
  published ranges, so it says nothing of the region. No DMI; the
  metadata address `169.254.169.254` answers 403 with `x-deny-reason:
  private_dest_ip`, from the session's egress filter, with or without the
  proxy, and Google's name for it does not resolve.
* **Hypervisor:** as in entry 1: Firecracker microVM on KVM, a container
  inside it (`docker`), kernel `6.18.44-fc-v37`, `ipv6.disable=1`. No DMI
  table; the kernel measured the TSC at 2100.000 MHz.
* **CPU:** Intel Xeon Scalable **Emerald Rapids** (family 6, model 0xcf,
  stepping 2), presented as what it is: every extension that `cpuid` claims
  runs, among them AVX-512 FP16 and BF16, AMX, SERIALIZE and MOVDIRI, and
  none runs that it does not claim (`make envcheck`). The brand string is
  masked (`Intel(R) Xeon(R) Processor @ 2.10GHz`, microcode `0x1`). `cpuid`
  gives L1d 48 KiB 12-way, L1i 32 KiB, L2 2 MiB 16-way and L3 260 MiB
  (266,240 KiB) 20-way. The TSC runs at the base clock, 2.1 GHz. Google
  Cloud's Emerald Rapids is the Xeon Platinum 8581C, of the C4 and N4
  series; the clock measured below fits C4 (3.1 GHz all cores, 4.0 at
  most) better than N4 (2.9 all cores). AMX-FP16, which Granite Rapids
  added, faults (tried by hand on 2026-09-25): the hardware is an Emerald
  Rapids, not the Granite Rapids of entry 3 under the same model. Measured
  (`make envcheck ENVCHECK=--slow`): L1d exactly 48 KiB at 1.4 to 1.6 ns
  (5 cycles), L2 about 1.6 MiB effective at 5.0 ns, L3 about 68 MiB
  effective at 33 to 73 ns, rising with the size: the VM gets part of the
  host's L3. Then memory at 120 to 260 ns. 4 vCPUs (4 cores, 1 thread per
  core, 1 socket), moved between the host's cores as in entry 1.
* **Clock:** measured 3.15 to 3.17 GHz on one core, 3.34 to 3.38 on
  average with all four busy (3.17 to 3.53 each): turbo above the nominal
  2.1 GHz. A chain of `add $1` (or `inc`) instructions, which entry 1
  was timed with, gave 16.5 GHz here: from Golden Cove on, the renamer does
  such an add itself, several of one chain a cycle. `make envcheck` now
  adds a register (`docs/envcheck.md`), which gives the figures above,
  and so does a chain of `imul`, 3 cycles each, at 1.05 to 1.13 G/s.
* **FMA:** 256-bit 6.3 to 7.0 G FMA instructions/s, 512-bit 5.6 to 6.9 G/s,
  2.0 to 2.2 and 1.9 to 2.1 a cycle of the scalar clock: two FMA units,
  and AVX-512 runs at about the scalar clock, where entry 1's ran at 2.5
  against 3.2 GHz.
* **Memory:** as in entry 1: 15.7 GiB of RAM (`MemTotal` 16,481,980 kB),
  no swap, the shell's cgroup (v1) limited to 13.36 GiB, a
  `virtio_balloon`. Bandwidth (STREAM triad over arrays of 520 MiB, twice
  the L3): 11.7 to 12.8 GB/s on one thread, 50 to 55 GB/s on all four.
  Arrays of 64 MiB, which `make envcheck` used before, gave twice as much
  on one thread: they were in the L3.
* **OS, disk space, restarts:** Ubuntu 24.04.4 LTS, x86_64, as `root`;
  29 GB of the session's allowance free after the session-start hook had
  installed the packages and built the hosts. No restart in the 26
  minutes it was watched.
* **Disk speed** (`make envcheck`, three fast runs and one slow): sequential
  write 657 to 809 MB/s; sequential read 1.7 to 2.2 GB/s of what was just
  written, and 279 MB/s to 2.4 GB/s after `drop_caches`, which varies as
  in entry 1. Random 4 KiB: 26,000 to 31,000 reads or 17,000 to 27,000
  writes a second on one thread, 58,000 to 76,000 and 61,000 to 79,000 on
  four, median 32 to 56 us, now and then up to 58 ms. 4 KiB write +
  `fdatasync`: 3,100 to 4,500 a second, 224 to 323 us on average, at most
  0.7 s. Small files: create 31,000 to 62,000, stat 740,000 to 1,080,000,
  read 384,000 to 436,000, delete 209,000 to 263,000 a second. Faster than
  entry 1 in all but the read of what was just written.
* **Tools present:** after the session-start hook (`cloud/SETUP.md`):
  gcc 13.3, clang 18.1, GNU make 4.3, git 2.43, Python 3.11, and every
  package of `cloud/SETUP.md`; `make doctor` passes in every scope.
* **perf (the Linux command):** as in entry 1: no hardware counters (no
  `cpu` device under `/sys/bus/event_source/devices`); `perf stat` counts
  software events only.
* **Network:** as in entry 1. `make envcheck`, four runs: GitHub 79 to
  126 MB/s, PyPI 11 to 121 MB/s, the SML/NJ site 26 to 33 MB/s, Ubuntu's
  releases 16 to 18 MB/s but twice 0.6 to 1.2 MB/s: the CDN, as in
  entry 1. The first byte after 0.3 to 0.8 s through the proxy (once
  1.4 s), mostly 80 to 100 ms from PyPI, which bypasses it.
* **Cores and neighbours** (`make envcheck`, four runs):
  * The 4 vCPUs are 4 cores most of the time: two that run integer adds
    at once keep 0.83 to 1.18 of the throughput each has alone. In one run
    a pair kept 0.68 in one round, and in another a cache line passed
    between two of them in 21 ns once: two threads of one core, for a
    while, as in entry 1.
  * Otherwise a cache line passes between two vCPUs in 69 to 285 ns, with
    a median of 190 to 198 ns in three runs and 103 ns in the fourth, and
    the same pair changes between rounds: the host moves the vCPUs, at
    about 200 ns probably between its sockets.
  * Neighbours cost little: steal 0.8 to 1.6% with all four vCPUs busy; a
    vCPU stopped for over 1 ms 2.5 to 3.1 times a second, at most 5 to
    18 ms.
* **`make check`:** 11 min 29 s from a clean tree (entry 1: about
  14.5 min). It passes, with the 10 INet6Sock socket checks skipped for
  want of IPv6, as in entry 1.

## 3. Claude Code on the web (Anthropic cloud), Granite Rapids, 2026-09-26

* **Fingerprint:** `GenuineIntel 6/207/2 on Granite Rapids, 4 CPUs, 15.7 GiB, KVMKVMKVM, kernel fc-v37`
* **Service:** as in entry 2, and the same session: it was resumed after a
  night, and the container restarted on this machine (at 13:27 UTC; it
  had also restarted on entry 2's the evening before, at 19:24). The disk
  was kept (the repository, the build, `~/.local/rune-hosts`, `/tmp`), the
  processes were not. The session-start hook runs `make envcheck` only at
  the start of a session, not on a resume, so it did not notice: a resumed
  session can land on another kind of machine behind the same cpuid.
* **Where** (`make envcheck`): **Google Cloud, region `us-central1`, a
  Firecracker microVM nested in a VM**, likely of the C4 series, which
  Google Cloud runs on Emerald Rapids and on Granite Rapids. As in entry 2:
  the direct egress in `34.172.0.0/15` of `us-central1` (two addresses
  seen), the proxy's address in none of Google Cloud's ranges, no DMI, the
  metadata address blocked.
* **Hypervisor:** as in entry 1.
* **CPU:** **Granite Rapids** (Xeon 6, Redwood Cove cores) under the
  Emerald Rapids model of entry 2: `cpuid` gives the same in all that
  `make envcheck` reads (family 6, model 0xcf, stepping 2, the extensions,
  the caches: L1d 48 KiB, L1i 32 KiB, L2 2 MiB, L3 260 MiB), and so do the
  brand string and the TSC of 2.1 GHz, presumably the model and nominal
  clock the VM was made with, which it keeps on newer hardware as N2 does
  in entry 1. Two signs that it cannot hide: AMX-FP16, which Granite
  Rapids added and `cpuid` does not claim, runs on every vCPU (it faulted
  on entry 2's machine), and the L1 instruction cache holds 64 KiB of code,
  Redwood Cove's, where `cpuid` says 32: straight-line code is fetched at
  106 to 137 bytes a ns up to 64 KiB and at 42 to 53 from 72 KiB (`make
  envcheck`, which measures both since this machine). Measured (`--slow`): L1d exactly 48 KiB at 1.5 ns;
  L2 about 1.6 MiB effective at 4.8 ns; L3 about 136 MiB effective, twice
  what entry 2's VM got, at 35 to 76 ns rising with the size; then memory
  at 170 to 245 ns. In one fast run the L1d came out at 40 KiB, while two
  vCPUs shared a core: another thread on the core shares the L1, which is
  why `make envcheck` now keeps the largest of three sweeps.
* **Clock:** 3.18 to 3.28 GHz on one core, 3.12 to 3.38 on average with all
  four busy (3.09 to 3.73 each), as on entry 2's Emerald Rapids.
* **FMA:** 256-bit 6.4 to 7.3 G FMA instructions/s, 512-bit 5.7 to 6.9 G/s,
  2.0 to 2.4 and 1.8 to 2.2 a cycle of the scalar clock: two FMA units, as
  in entry 2.
* **Memory:** as in entry 2: 15.7 GiB, no swap, cgroup limit 13.36 GiB.
  Triad 12.0 to 12.3 GB/s on one thread, 51.6 to 53.0 GB/s on four.
* **Disk speed** (`make envcheck`, two fast runs and one slow): sequential
  write 669 to 1,094 MB/s; read 1.85 to 2.13 GB/s of what was just
  written, 447 MB/s to 2.57 GB/s after `drop_caches`. Random 4 KiB: 23,800
  to 33,500 reads or 19,600 to 26,600 writes a second on one thread, 59,700
  to 68,200 and 64,400 to 67,900 on four. 4 KiB write + `fdatasync`: 3,900
  to 4,700 a second, 212 to 257 us on average, at most 0.4 s. Small files:
  create 36,000 to 79,000, stat 710,000 to 975,000, read 309,000 to
  414,000, delete 195,000 to 258,000 a second. About as entry 2.
* **Network:** as in entry 2: GitHub 82 to 125 MB/s, PyPI 62 to 141 MB/s,
  the SML/NJ site 32 to 33 MB/s, Ubuntu's releases 4.7 to 78 MB/s.
* **Cores and neighbours** (`make envcheck`, three runs): in one run two
  vCPUs kept 0.64 to 0.69 of their throughput in all three rounds and
  another pair fell to 0.44 once: two threads of one core, for the length
  of the run. In the others every pair kept about 0.75 or more. A cache
  line passes in 60 to 238 ns, median 196 ns in the fast runs and 89 in the
  slow one; steal 0.7 to 1.4% with all
  four busy, pauses over 1 ms 1.6 to 3.4 times a second, at most 4 to
  14 ms.
* **`make check`:** 7 min 51 s, rebuilding the compilers (the tree had the
  middle-end of 2026-09-25, which entry 2's 11.5 min did not). It passes,
  with the 10 INet6Sock socket checks skipped for want of IPv6.
