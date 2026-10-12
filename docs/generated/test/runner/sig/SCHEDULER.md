# signature SCHEDULER

[Running tests](../README.md) &rsaquo; Running tests &rsaquo; **SCHEDULER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 7 of 7 entries documented |
| Tests | not listed |
| Source | [lib/test/runner/scheduler\_sig.sml](../../../../../lib/test/runner/scheduler_sig.sml) |

## Synopsis

```sml
signature SCHEDULER
structure Scheduler :> SCHEDULER
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Scheduler`](../str/Scheduler.md) | The scheduler: priorities by critical path, admission by CPUs, memory, pools and exclusion, and a simulation on a clock of its own. | [lib/test/runner/scheduler.sml](../../../../../lib/test/runner/scheduler.sml) |

Which jobs to start (docs/plans/unit-testing.md, D12): a pure function of
the jobs, what has finished, what runs and what is free, so that it can be
tested on a simulated clock.

A job takes CPUs and megabytes of memory while it runs, may hold named
pools (mutexes: two jobs that name one never overlap), may be exclusive
(it runs alone), and may wait for other jobs. Its priority is the critical
path: the longest chain of costs from it to the end of the run, so that
among jobs with no edges the longest starts first (Graham's LPT). A job
that failed last time starts before any other. An exclusive job that is
next lets the running jobs drain, and nothing starts in front of it.

## Interface

<pre>
signature SCHEDULER =
sig
  type <a href="#type-job">job</a> = {<a href="#fld-job.cost">cost</a> : real, <a href="#fld-job.cpus">cpus</a> : int, <a href="#fld-job.memory">memory</a> : int, <a href="#fld-job.pools">pools</a> : string list, <a href="#fld-job.exclusive">exclusive</a> : bool,
              <a href="#fld-job.failedlast">failedLast</a> : bool, <a href="#fld-job.deps">deps</a> : int list}
  type <a href="#type-free">free</a> = {<a href="#fld-free.cpus">cpus</a> : int, <a href="#fld-free.memory">memory</a> : int, <a href="#fld-free.held">held</a> : string list}
  type <a href="#type-plan">plan</a>
  val <a href="#val-plan">plan</a> : job vector -&gt; plan
  val <a href="#val-priority">priority</a> : plan * int -&gt; real
  val <a href="#val-next">next</a> : plan * {<a href="#fld-next.waiting">waiting</a> : int list, <a href="#fld-next.finished">finished</a> : int list, <a href="#fld-next.running">running</a> : int list, <a href="#fld-next.free">free</a> : free} -&gt; int list
  val <a href="#val-simulate">simulate</a> : plan * {<a href="#fld-simulate.cpus">cpus</a> : int, <a href="#fld-simulate.memory">memory</a> : int} -&gt; real vector * real
end
</pre>

### <a name="type-job"></a>`job`

```sml
type job = {cost : real, cpus : int, memory : int, pools : string list, exclusive : bool,
            failedLast : bool, deps : int list}
```

A job as the scheduler sees it: its cost, what it takes and holds, and
the jobs it waits for.

The cost is in seconds, from the history. `deps` are the indices of
the jobs it waits for; `exclusive` runs it alone.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-job.cost"></a>`cost` | `real` |  |
| <a name="fld-job.cpus"></a>`cpus` | `int` |  |
| <a name="fld-job.memory"></a>`memory` | `int` |  |
| <a name="fld-job.pools"></a>`pools` | `string list` |  |
| <a name="fld-job.exclusive"></a>`exclusive` | `bool` |  |
| <a name="fld-job.failedlast"></a>`failedLast` | `bool` |  |
| <a name="fld-job.deps"></a>`deps` | `int list` |  |

### <a name="type-free"></a>`free`

```sml
type free = {cpus : int, memory : int, held : string list}
```

What the machine has free: CPUs and megabytes, and the pools held.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-free.cpus"></a>`cpus` | `int` |  |
| <a name="fld-free.memory"></a>`memory` | `int` |  |
| <a name="fld-free.held"></a>`held` | `string list` |  |

### <a name="type-plan"></a>`plan`

```sml
type plan
```

A run's plan: the jobs and their priorities.

### <a name="val-plan"></a>`plan`

```sml
val plan : job vector -> plan
```

`plan jobs` is the plan of `jobs`, numbered by their places.

**Raises** [`Fail`](../../../basis/sig/GENERAL.md#exn-fail) if a job waits for itself, or for one that waits for
it.

### <a name="val-priority"></a>`priority`

```sml
val priority : plan * int -> real
```

`priority (p, i)` is job `i`'s priority: its cost and the longest chain
of costs after it, and more than every other for a job that failed
last time.

**Example** `Real.== (priority (plan (Vector.fromList [{cost = 2.0, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = []}]), 0), 2.0)`

### <a name="val-next"></a>`next`

```sml
val next : plan * {waiting : int list, finished : int list, running : int list, free : free} -> int list
```

`next (p, {waiting, finished, running, free})` is the jobs among
`waiting` to start now, the highest priority first.

A job may start once every job it waits for is in `finished`, when it
fits what is free, and when no job in `running` holds a pool of its.

A job that takes more than the machine has starts alone when nothing
runs, so that no job waits forever.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-next.waiting"></a>`waiting` | `int list` |  |
| <a name="fld-next.finished"></a>`finished` | `int list` |  |
| <a name="fld-next.running"></a>`running` | `int list` |  |
| <a name="fld-next.free"></a>`free` | `free` |  |

### <a name="val-simulate"></a>`simulate`

```sml
val simulate : plan * {cpus : int, memory : int} -> real vector * real
```

`simulate (p, {cpus, memory})` is when each job would start, and the
makespan, in the schedule [`next`](#val-next) makes.

The machine has `cpus` and `memory`, and each job takes its cost.

**Example** `Real.== (#2 (simulate (plan (Vector.fromList [{cost = 1.0, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = []}]), {cpus = 4, memory = 100})), 1.0)`

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-simulate.cpus"></a>`cpus` | `int` |  |
| <a name="fld-simulate.memory"></a>`memory` | `int` |  |

---

<sub>Generated by runedoc from lib/test/runner/scheduler\_sig.sml; do not edit.</sub>
