# signature TIMER

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **TIMER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | 27 checks of 8 entries |
| Source | [lib/basis/sig\_timer.sml](../../../../lib/basis/sig_timer.sml) |

## Synopsis

```sml
signature TIMER
structure Timer : TIMER
```

| Implementation |  | Source |
| --- | --- | --- |
| `Timer` | Timer: how long something took. | [lib/basis/timer.sml](../../../../lib/basis/timer.sml) |

Stopwatches: how much processor time and how much wall-clock time have
passed since a timer was started.

A timer is started, not read and reset: `startCPUTimer ()` and
`startRealTimer ()` take a reading of the clocks, and [`checkCPUTimer`](#val-checkcputimer) and
[`checkRealTimer`](#val-checkrealtimer) give the time since, as often as one likes. The two
`total` timers are the ones that were started when the program was, so
they measure the whole run.

Processor time is split into the time the program spent and the time the
system spent on its behalf, and [`checkCPUTimes`](#val-checkcputimes) separates out what the
garbage collector took.

> **Reading** `TIMER/only-properties-are-checked`. What a timer reads is not a
> value a test can predict; the suite checks that times are not negative,
> that they do not go backwards, and that the equivalences the specification
> states hold. A system that does not account for processor time may report
> real time here.

## Interface

<pre>
signature TIMER =
sig
  type <a href="#type-cpu_timer">cpu_timer</a>

  type <a href="#type-real_timer">real_timer</a>

  val <a href="#val-startcputimer">startCPUTimer</a> : unit -&gt; cpu_timer

  val <a href="#val-checkcputimes">checkCPUTimes</a> : cpu_timer
                      -&gt; {<a href="#fld-checkcputimes.nongc">nongc</a> : {usr : Time.time, sys : Time.time},
                          <a href="#fld-checkcputimes.gc">gc</a> : {usr : Time.time, sys : Time.time}}

  val <a href="#val-checkcputimer">checkCPUTimer</a> : cpu_timer -&gt; {<a href="#fld-checkcputimer.usr">usr</a> : Time.time, <a href="#fld-checkcputimer.sys">sys</a> : Time.time}

  val <a href="#val-checkgctime">checkGCTime</a> : cpu_timer -&gt; Time.time

  val <a href="#val-totalcputimer">totalCPUTimer</a> : unit -&gt; cpu_timer

  val <a href="#val-startrealtimer">startRealTimer</a> : unit -&gt; real_timer

  val <a href="#val-checkrealtimer">checkRealTimer</a> : real_timer -&gt; Time.time

  val <a href="#val-totalrealtimer">totalRealTimer</a> : unit -&gt; real_timer
end
</pre>

### <a name="type-cpu_timer"></a>`cpu_timer`

```sml
type cpu_timer
```

The type of a processor-time timer.

### <a name="type-real_timer"></a>`real_timer`

```sml
type real_timer
```

The type of a wall-clock timer, a [`Time.time`](../sig/TIME.md#type-time) in the same way.

### <a name="val-startcputimer"></a>`startCPUTimer`

```sml
val startCPUTimer : unit -> cpu_timer
```

`startCPUTimer ()` is a timer that counts processor time from now.

<details><summary>Tests (3)</summary>

For `Timer`, in [tests/basis/timer.sml](../../../../tests/basis/timer.sml): `starts` &middot; `starts-near-zero` &middot; `later-timer-reads-less`

</details>

### <a name="val-checkcputimes"></a>`checkCPUTimes`

```sml
val checkCPUTimes : cpu_timer
                    -> {nongc : {usr : Time.time, sys : Time.time},
                        gc : {usr : Time.time, sys : Time.time}}
```

`checkCPUTimes t` is the processor time since `t` was started, split into the collector's share and the rest.

`usr` is the time the program itself ran, `sys` the time the system
spent for it.

> **Implementation** `Timer.checkCPUTimes/gc-from-the-collector`. The VM adds
> up the processor time of every collection, user and system apart, and
> `gc` is how much of that has passed since the timer started; `nongc` is
> the rest. A collection that grows the heap counts once.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-checkcputimes.nongc"></a>`nongc` | `{usr : Time.time, sys : Time.time}` |  |
| <a name="fld-checkcputimes.gc"></a>`gc` | `{usr : Time.time, sys : Time.time}` |  |

<details><summary>Tests (5)</summary>

For `Timer`, in [tests/basis/timer.sml](../../../../tests/basis/timer.sml): `non-negative` &middot; `sum-is-checkCPUTimer` &middot; `does-not-go-back` &middot; `gc-is-part-of-the-whole` &middot; `grows-while-computing`

</details>

### <a name="val-checkcputimer"></a>`checkCPUTimer`

```sml
val checkCPUTimer : cpu_timer -> {usr : Time.time, sys : Time.time}
```

`checkCPUTimer t` is the processor time since `t` was started, user and system time apart.

It counts the collector's share in, where [`checkCPUTimes`](#val-checkcputimes) reports it
separately.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-checkcputimer.usr"></a>`usr` | `Time.time` |  |
| <a name="fld-checkcputimer.sys"></a>`sys` | `Time.time` |  |

<details><summary>Tests (3)</summary>

For `Timer`, in [tests/basis/timer.sml](../../../../tests/basis/timer.sml): `non-negative` &middot; `grows-while-computing` &middot; `does-not-go-back`

</details>

### <a name="val-checkgctime"></a>`checkGCTime`

```sml
val checkGCTime : cpu_timer -> Time.time
```

`checkGCTime t` is the processor time the collector took since `t` was started.

> **Implementation** `Timer.checkGCTime/user-time-of-the-collections`. It is
> the `usr` field of what [`checkCPUTimes`](#val-checkcputimes) reports under `gc`; the system
> time of a collection is in that record and not here.

<details><summary>Tests (4)</summary>

For `Timer`, in [tests/basis/timer.sml](../../../../tests/basis/timer.sml): `non-negative` &middot; `is-gc-usr` &middot; `part-of-usr` &middot; `does-not-go-back`

</details>

### <a name="val-totalcputimer"></a>`totalCPUTimer`

```sml
val totalCPUTimer : unit -> cpu_timer
```

`totalCPUTimer ()` is the timer that was started when the program was.

> **Implementation** `Timer.totalCPUTimer/from-process-start`. The
> "system-dependent initialization time" is the start of the process, so
> the timer's base is zero processor time and what it reports is what the
> whole run has used.

<details><summary>Tests (3)</summary>

For `Timer`, in [tests/basis/timer.sml](../../../../tests/basis/timer.sml): `non-negative` &middot; `includes-earlier-computation` &middot; `does-not-go-back`

</details>

### <a name="val-startrealtimer"></a>`startRealTimer`

```sml
val startRealTimer : unit -> real_timer
```

`startRealTimer ()` is a timer that counts wall-clock time from now.

<details><summary>Tests (2)</summary>

For `Timer`, in [tests/basis/timer.sml](../../../../tests/basis/timer.sml): `starts` &middot; `starts-near-zero`

</details>

### <a name="val-checkrealtimer"></a>`checkRealTimer`

```sml
val checkRealTimer : real_timer -> Time.time
```

`checkRealTimer t` is the wall-clock time since `t` was started.

<details><summary>Tests (4)</summary>

For `Timer`, in [tests/basis/timer.sml](../../../../tests/basis/timer.sml): `non-negative` &middot; `does-not-go-back` &middot; `measures-real-time` &middot; `at-most-the-time-around`

</details>

### <a name="val-totalrealtimer"></a>`totalRealTimer`

```sml
val totalRealTimer : unit -> real_timer
```

`totalRealTimer ()` is the wall-clock timer that was started when the program was.

> **Implementation** `Timer.totalRealTimer/from-initialisation`. It counts
> from the moment the library was initialised, just before the program's
> own code begins.

<details><summary>Tests (3)</summary>

For `Timer`, in [tests/basis/timer.sml](../../../../tests/basis/timer.sml): `non-negative` &middot; `includes-earlier-time` &middot; `does-not-go-back`

</details>

## See also

[`TIME`](../sig/TIME.md), [`OS_PROCESS`](../sig/OS_PROCESS.md)

---

<sub>Generated by runedoc from lib/basis/sig\_timer.sml; do not edit.</sub>
