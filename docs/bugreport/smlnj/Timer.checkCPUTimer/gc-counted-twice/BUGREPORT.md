# SML/NJ 110.99.9: `Timer.checkCPUTimer` counts garbage-collection time twice

## Status: fixed upstream in the new series, not in 110.x

SML/NJ has fixed this bug in its new series, but not in the 110.x line
that Rune's hosts use.
* **The fix:** issue #456 of
  [smlnj/smlnj](https://github.com/smlnj/smlnj), "`Timer.checkCPUTimer`
  double-counts garbage collector time", fixed by commit `03b38f8e`
  on 2026-08-31, which also adds the system time of the collector.
* **Releases:** the first tag with the fix is `v2026.3-beta`; the newest
  release, `v2026.2`, does not have it.
* **110.x:** [smlnj/legacy](https://github.com/smlnj/legacy) at `6ed5a0a`
  (2026-09-13) has the same `internal-timer.sml` and `gettime.c` as
  110.99.9, so the bug is still there.

**What is worth sending SML/NJ is a request to backport the fix to 110.x**,
or nothing if 110.x takes only fixes of the compiler. The program below
shows the bug on 110.99.9.

## Summary

* **The trigger:** any program that collects garbage, timed with
  `Timer.checkCPUTimer` or with the `nongc` part of `Timer.checkCPUTimes`.
* **What goes wrong:** the `nongc` user time is the process's whole user
  time, collections included, and `checkCPUTimer` adds the collections'
  time to it again. A program that spends half its time in the collector
  is reported to have used about twice the processor time it did.
* **Required behaviour:** the
  [Basis `TIMER` specification](https://smlfamily.github.io/Basis/timer.html)
  splits the time into what the program used outside the collector
  (`nongc`) and what the collector used (`gc`), and `checkCPUTimer` is
  their sum, the time the process used.

## Environment

* **SML/NJ:** 110.99.9 (the build dated November 4, 2025), 64-bit, built
  from the sources of `smlnj.cs.uchicago.edu/dist/working/110.99.9` by
  Rune's `scripts/fetch-hosts.sh`.
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM (kernel
  6.18.44-fc), gcc 13.3.0.
* **Basis Library: SML/NJ's own.** The program is standalone,
  `sml bug.sml`, with nothing of Rune involved.

## The program

`bug.sml` times some work that keeps a large structure alive, so that
collections cost, and compares the user time `Timer` reports with the
user time `Posix.ProcEnv.times` reports. The two should be about equal:

```
$ sml bug.sml
user time, from times():             3860 ms
user time, from Timer.checkCPUTimer: 7640 ms
  of which nongc: 3858 ms, gc: 3781 ms
```

Three runs gave the same picture (3880/7683/3881/3802 and
3740/7394/3734/3659 ms): `nongc` alone is the whole user time, and
`checkCPUTimer` is larger by the time of the collections.

## The cause

The runtime's `gettime` (`base/runtime/c-libs/smlnj-time/gettime.c`)
returns the user time of the process from `getrusage`, its system time,
and the time the collector has used (`vp_gcTime`):

```c
GetCPUTime (&t, &s);
cpuT = ML_AllocNanoseconds(msp, t.seconds, t.uSeconds);
sysT = ML_AllocNanoseconds(msp, s.seconds, s.uSeconds);
gcT = ML_AllocNanoseconds(msp, vsp->vp_gcTime->seconds, vsp->vp_gcTime->uSeconds);
```

The user time from `getrusage` already includes the collector's.
`system/Basis/Implementation/internal-timer.sml` nevertheless takes it
for the time outside the collector, and `checkCPUTimer` adds the two:

```sml
fun getTime () = let
      val (usr, sys, gc) = gettime' ()
      in {
        nongc = { usr = mkTime usr, sys = mkTime sys },
        gc    = { usr = mkTime gc, sys = Time.zeroTime }
      } end
...
fun checkCPUTimer tmr = let
    val t = checkCPUTimes tmr
in
    #nongc t ++ #gc t
end
```

The collector's system time is not measured at all: it is in `nongc`'s
`sys`, and `gc`'s `sys` is always zero.

## The fix

Commit `03b38f8e` of smlnj/smlnj makes `gettime` return the collector's
user and system time apart (`vp_gcUsrTime`, `vp_gcSysTime`) and subtracts
them from the process's times:

```sml
val (usr, sys, gcUsr, gcSys) = gettime' ()
in {
  nongc = { usr = mkTime(usr - gcUsr), sys = mkTime(sys - gcSys) },
  gc    = { usr = mkTime gcUsr, sys = mkTime gcSys }
} end
```

For 110.x the smallest fix is the first half alone, in
`internal-timer.sml`: `nongc = { usr = mkTime (usr - gc), ... }`. It has
not been tried against a build of either branch: this machine has only
110.99.9.

## How Rune met it

Rune, a self-hosting Standard ML compiler, checks its Basis Library by
compiling it with SML/NJ as well (the `xc1` configurations of its Basis
Library suite). There the library's processor-time primitives are written
on SML/NJ's `Timer` (`tests/basis/host/rune-prim.sml`), so on SML/NJ
Rune's `Timer` reports the collector's time twice too. None of the
suite's checks compares the times with the operating system's, so the
suite does not see it; it was found while looking into another failure of
`Timer.totalCPUTimer` in that configuration, which came from how
`rune-prim.sml` kept a timer across a saved heap image and is fixed in
Rune.
