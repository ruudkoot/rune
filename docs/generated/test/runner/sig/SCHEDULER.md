# signature SCHEDULER

[Running tests](../README.md) &rsaquo; Running tests &rsaquo; **SCHEDULER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 11 of 11 entries documented |
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

Which jobs to start (docs/plans/unit-testing.md, D12): the jobs of a run,
what has ended and what is free decide it, so that it can be tested on a
simulated clock.

A job takes CPUs and megabytes of memory while it runs, may hold named
pools (mutexes: two jobs that name one never overlap), may be exclusive
(it runs alone), and may wait for other jobs. Its priority is the critical
path: the longest chain of costs from it to the end of the run, so that
among jobs with no edges the longest starts first (Graham's LPT). A job
that failed last time starts before any other. An exclusive job that is
next lets the running jobs drain, and nothing starts in front of it.

A run's state is kept as it goes, so that a run of thousands of jobs costs
little at each start and end: the jobs each waits for are counted down,
and the jobs that may start are kept in the order of their priorities.

## Interface

<pre>
signature SCHEDULER =
sig
  type <a href="#type-job">job</a> = {<a href="#fld-job.cost">cost</a> : real, <a href="#fld-job.cpus">cpus</a> : int, <a href="#fld-job.memory">memory</a> : int, <a href="#fld-job.pools">pools</a> : string list, <a href="#fld-job.exclusive">exclusive</a> : bool,
              <a href="#fld-job.failedlast">failedLast</a> : bool, <a href="#fld-job.deps">deps</a> : int list}
  type <a href="#type-plan">plan</a>
  val <a href="#val-plan">plan</a> : job vector -&gt; plan
  val <a href="#val-priority">priority</a> : plan * int -&gt; real
  type <a href="#type-state">state</a>
  val <a href="#val-start">start</a> : plan -&gt; state
  val <a href="#val-admit">admit</a> : state * {<a href="#fld-admit.cpus">cpus</a> : int, <a href="#fld-admit.memory">memory</a> : int} -&gt; int list
  val <a href="#val-ended">ended</a> : state * int * bool -&gt; int list
  val <a href="#val-retry">retry</a> : state * int -&gt; unit
  val <a href="#val-finished">finished</a> : state -&gt; bool
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
it, or for no job.

### <a name="val-priority"></a>`priority`

```sml
val priority : plan * int -> real
```

`priority (p, i)` is job `i`'s priority: its cost and the longest chain
of costs after it, and more than every other for a job that failed
last time.

**Example** `Real.== (priority (plan (Vector.fromList [{cost = 2.0, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = []}]), 0), 2.0)`

### <a name="type-state"></a>`state`

```sml
type state
```

A run under way: which jobs wait, run and have ended, and what the
running ones take.

### <a name="val-start"></a>`start`

```sml
val start : plan -> state
```

`start p` is the state of a run of `p` before any job has started.

### <a name="val-admit"></a>`admit`

```sml
val admit : state * {cpus : int, memory : int} -> int list
```

`admit (s, {cpus, memory})` is the jobs to start now, the highest
priority first, on a machine of `cpus` and `memory`; they are running
from then on.

A job may start once every job it waits for has ended well, when it
fits what the running jobs leave free, and when no running job holds a
pool of its. A job that takes more than the machine has starts alone
when nothing runs, so that no job waits forever.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-admit.cpus"></a>`cpus` | `int` |  |
| <a name="fld-admit.memory"></a>`memory` | `int` |  |

### <a name="val-ended"></a>`ended`

```sml
val ended : state * int * bool -> int list
```

`ended (s, i, ok)` records that job `i` ended, well when `ok`, and is
the jobs that will now never start.

Those are the jobs that wait, directly or not, for a job that did not
end well.

### <a name="val-retry"></a>`retry`

```sml
val retry : state * int -> unit
```

`retry (s, i)` puts the running job `i` back among those that may
start, as if it had not run.

### <a name="val-finished"></a>`finished`

```sml
val finished : state -> bool
```

`finished s` says whether no job waits or runs.

### <a name="val-simulate"></a>`simulate`

```sml
val simulate : plan * {cpus : int, memory : int} -> real vector * real
```

`simulate (p, {cpus, memory})` is when each job would start, and the
makespan, in the schedule [`admit`](#val-admit) makes.

The machine has `cpus` and `memory`, and each job takes its cost.

**Example** `Real.== (#2 (simulate (plan (Vector.fromList [{cost = 1.0, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = []}]), {cpus = 4, memory = 100})), 1.0)`

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-simulate.cpus"></a>`cpus` | `int` |  |
| <a name="fld-simulate.memory"></a>`memory` | `int` |  |

---

<sub>Generated by runedoc from lib/test/runner/scheduler\_sig.sml; do not edit.</sub>
