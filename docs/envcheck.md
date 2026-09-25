# envcheck: what machine is this?

`make envcheck` (`scripts/envcheck.sh`) reports on the machine it runs on:
what it is, what it can run and how fast it is. It is meant for a new cloud
session (`cloud/SETUP.md`), where the machine is not the one of the last
session, and for any machine whose figures are wanted in
`cloud/ENVIRONMENT.md`. It installs nothing and writes only to a temporary
directory; the measurements are `scripts/envcheck.c`, compiled when it runs.

```
make envcheck                              # under a minute
make envcheck ENVCHECK=--slow              # a few minutes, steadier figures
make envcheck ENVCHECK=--markdown          # also an entry for ENVIRONMENT.md
make envcheck ENVCHECK="--json out.json"   # also every result as JSON
make envcheck ENVCHECK=--commit-test       # also how much memory can be used
```

Every result is a line `key value`; `--json` writes the same keys.

## What it measures, and how

### System

The kernel, the distribution, PID 1 (systemd, or a sandbox's agent), the
uptime (a cloud container can restart within a session), the hypervisor and
container as `systemd-detect-virt`, DMI and the kernel command line tell it,
markers of the environment (`CLAUDE_CODE_REMOTE`, `CI`, ...), whether a
proxy is set, the memory, swap and overcommit, the memory and CPU limits of
the process's cgroup and of every group above it (v1 and v2: a limit can be
set in either), a balloon device, and the free space of the repository,
`$TMPDIR`, `$HOME` and `/dev/shm`.

### CPU identity and instruction set

* **`cpuid`:** vendor, family, model, stepping, brand, the hypervisor's
  signature (leaf `0x40000000`), the caches (leaf 4, or `0x8000001d` on
  AMD) and the topology as presented (leaf `0xb`). `cpu.uarch` names the
  microarchitecture from a table in `envcheck.c`; a model that is not in
  it is reported as something to add.
* **Instructions that run:** each extension is tried by executing one of its
  instructions under a `SIGILL` handler, and compared with what `cpuid`
  claims and what the kernel has enabled (`XCR0`). A hypervisor can hide an
  extension in `cpuid` (a CPU template) but cannot stop its instructions
  from running, so `MISMATCH: runs but cpuid does not claim it` means the
  hardware is newer than the model presented, and
  `cpu.uarch_by_instructions` names the generation the instructions that
  run point to. The reverse, claimed but faulting, is reported as a failure.
  `lzcnt`, `cx16` and `rtm` are only read: running them proves nothing
  (`lzcnt` runs as `bsr` on a CPU without it).

### Cores, caches and neighbours

* **Pairs (`pairs`):** a loop of eight independent adds, which keeps the
  integer ports of a core busy, runs on each CPU alone and then on each pair
  at once, three times. Two hyperthreads of one core share those ports, so
  each keeps about half its throughput; two cores keep all of it. A pair
  below 0.75 in every round is always on one core
  (`pairs.always_sharing_a_core`); below it in some rounds, the host put the
  two vCPUs on one core for a while (`pairs.sometimes_sharing_a_core`), as
  it does on Claude Code on the web.
* **Ping-pong (`pingpong`):** two threads hand a cache line back and forth.
  About 20 ns one way is one core, 40 to 80 ns one socket, 120 ns or more
  another socket. Each pair is measured three times; a pair whose figure
  changes between rounds has been moved by the host, and the summary counts
  the rounds at 30 ns or less.
* **Cache curve (`cachecurve`):** the latency of a pointer chase through a
  random cycle of cache lines, for buffers from 4 KiB up. Each step up is a
  cache level; the last value is the latency of memory. In a VM the step
  of the L3 can come far below the size `cpuid` reports: the VM shares it.
* **Cache sizes (`cachesizes`):** the same chase at finer steps, over
  memory that asks for huge pages so that TLB misses blur the steps less.
  The size of a level is the last one before the latency crosses the
  geometric middle of its plateau and the next. L1 has a sharp edge and
  comes out exact, and is measured in every run; L2 and L3 fill up
  gradually, so their sizes are effective ones, measured with `--slow`. A
  size that differs from `cpuid` (the L1 exactly, the others by more than
  half) is reported: a hypervisor's CPU template can present another CPU's
  caches, and a VM gets only part of a shared L3.
* **Jitter (`jitter`):** a thread on every CPU reads the clock in a loop and
  counts the gaps over 100 us and over 1 ms, which are the times it was not
  running; with the steal time of `/proc/stat` over the same seconds, and
  over the whole run (`cpu.steal_during_run`), that is what neighbours cost.

### Speed

* **Clock (`clock`):** a chain of dependent adds runs one add a cycle, so
  adds per second is the clock: on one core, on all at once, and five times
  on one core, whose spread is another sign of neighbours. The adds add a
  register: from Golden Cove on (Alder Lake, Sapphire and Emerald Rapids)
  the renamer does an add of an immediate, or an `inc`, itself, several of
  one chain a cycle, and such a chain gave 16 GHz on an Emerald Rapids
  (`cloud/ENVIRONMENT.md`). The adds of the pairs add a register for the
  same reason.
* **FMA (`fma`):** 12 independent FMAs a round, 256 and 512 bits wide, in FMA
  instructions a cycle of the scalar clock: 2 is two FMA units at full
  clock; less for 512 bits is fewer units or the lower clock of AVX-512.
* **Memory bandwidth (`membw`):** copy and triad (STREAM's) over arrays far
  larger than the caches, the best of repeated passes, on one thread and on
  every CPU. An array is at least twice the L3 that `cpuid` reports, which
  on a large server part is over 256 MiB (arrays of 64 MiB measured the L3
  of an Emerald Rapids), as long as the three take at most a quarter of the
  memory, or of the cgroup's limit.
* **Disk (`disk`):** in `$ENVCHECK_DIR` (default: the temporary directory):
  sequential write with `O_DIRECT` and `fsync`, sequential read of it, a cold
  read after dropping the page cache (as root), random 4 KiB reads and
  writes on one thread and on several with median, 99th percentile and
  worst latency, 4 KiB appends each made durable with `fdatasync`, and the
  creation, `stat`, reading and deletion of many small files.
* **Network:** the start of a file from GitHub, PyPI, the SML/NJ site and
  Ubuntu's releases, with the time to the first byte and the speed after
  it. Each transfer has a size and a time cap; a source that does not
  answer is reported, not a failure. Only the start of a file is taken:
  a CDN can serve the start of a popular file fast and the rest slowly.

### Where it runs

Clues to the cloud, the region and the kind of VM, and a guess made of
them (`where.guess`), which says which clue it rests on:

* **DMI** (`/sys/class/dmi/id/sys_vendor`): Google, Amazon EC2, Microsoft,
  in a VM of the cloud itself; absent in a microVM or a VM nested in
  another.
* **Metadata endpoints:** AWS's and Azure's at `169.254.169.254`, Google's
  at `metadata.google.internal`; one that answers names the provider, and
  a sandbox usually blocks them.
* **Egress:** the address the traffic leaves from, its network's owner and
  its city, from ipinfo.io (a request to it; `ENVCHECK_NO_EGRESS=1` leaves
  it out, and the two below), asked three times: the address can rotate,
  and a database can place one of them elsewhere, so the region comes from
  the commonest city. Behind a proxy that is the proxy's, which need not be
  where the VM is; so where a proxy is set, a connection that bypasses it
  is tried as well (`where.egress_direct`), which a sandbox may allow for
  a few hosts or not at all. A small table in `envcheck.sh` names the
  region a provider has in that city; add to it.
* **Published ranges:** Google Cloud (`cloud.json`) and AWS
  (`ip-ranges.json`) publish the region of each of their address ranges;
  an egress address in one of them names the provider and the region
  exactly (`where.range_direct`, `where.range_egress`), and the guess rests
  on it before the city, the direct egress before the proxy's. An address
  in neither, such as a proxy's own block that Google announces, says
  nothing of the region: on Claude Code on the web the proxy's address is
  placed in Columbus (`us-east5`), the direct one in `us-central1`.
* **The nominal clock** (`tsc: Detected` in the kernel log): the clock of
  the CPU model the VM was given, which it keeps when it is moved to other
  hardware. With a CPU model older than the instructions that run (above),
  it tells which model that is: Google Cloud's N2 keeps a VM's Cascade Lake
  model, clock and all, on the Ice Lake hosts that followed.

### Committable memory (`--commit-test`)

A child process asks to be the first the OOM killer takes, then allocates
and touches 256 MiB at a time, writing the total to a file after each step,
until the kernel kills it or it reaches RAM and swap together. It runs only
when asked for and last of all, after everything else is reported: the
kernel may kill other processes of the shell's cgroup too, or the whole
container may restart. Without `--commit-test` the report ends by saying
it was not run.

## Fast and slow

| | fast (default) | `--slow` |
|---|---|---|
| clock, FMA | 1 s | 4 s |
| pairs | 0.2 s a pair, in three rounds | 1 s a pair, in three rounds |
| ping-pong | 20,000 rounds | 200,000 rounds |
| cache curve | up to 64 MiB | up to 512 MiB |
| cache sizes | L1 | L1, L2, L3 |
| memory bandwidth | 64 MiB arrays (or twice the L3), 0.4 s | 512 MiB arrays (or twice the L3), 2 s |
| jitter | 3 s | 10 s |
| disk | 256 MiB, 0.5 s a test, 2,000 files | 2 GiB, 3 s a test, 20,000 files |
| network | 16 MB or 3 s a source | 100 MB or 15 s a source |

The fast mode must finish within a minute and says so when it does not.
With every CPU pair tested, the pair tests grow with the square of the CPU
count: on more than 24 CPUs only CPU 0 is paired with the others.

## A known machine, or a new one

The report ends with a fingerprint: vendor, family/model/stepping, CPU
count, RAM, hypervisor signature and the kernel's flavour. An entry of
`cloud/ENVIRONMENT.md` carries the fingerprint of its machine in a line
`Fingerprint: ...`; when none matches, the report says so, and `--markdown`
prints an entry to start from. The script never edits that file: an entry
is checked and written by hand.

## When it fails

Every part runs on its own, and a part that cannot run is listed at the
end under *envcheck could not do everything here*, with the reason: no C
compiler, a probe that timed out or crashed, an architecture without its
probes, a CPU model missing from the table, a value outside what is
plausible, too little disk space, or a fast run over a minute. The exit
status is then 2 and the report asks the agent that ran it to make the
script work there and to commit the fix. The x86-64 probes need GCC or
Clang; on other architectures the commands that read `cpuid` or run
instructions of their own report themselves unsupported, and the rest runs.
