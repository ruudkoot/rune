# signature POSIX_PROCESS

[The Standard ML Basis Library](../README.md) &rsaquo; **POSIX_PROCESS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 22 entries documented |
| Tests | 50 checks of 16 entries |
| Source | [lib/basis/sig\_posix\_process.sml](../../../../lib/basis/sig_posix_process.sml) |

## Synopsis

```sml
signature POSIX_PROCESS
structure Posix.Process : POSIX_PROCESS
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.Process` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

signature POSIX\_PROCESS, transcribed from
<https://smlfamily.github.io/Basis/posix-process.html>

Uses BIT\_FLAGS (spec-sigs/BIT\_FLAGS.sml), which has to be loaded
first: the page specifies `structure W : sig include BIT_FLAGS val untraced : flags end`. The type signal is left flexible, as on the page; POSIX fixes
it to Signal.signal (spec-sigs/POSIX.sml).

## Interface

<pre>
signature POSIX_PROCESS =
sig
  eqtype <a href="#type-signal">signal</a>
  eqtype <a href="#type-pid">pid</a>

  val <a href="#val-wordtopid">wordToPid</a> : SysWord.word -&gt; pid
  val <a href="#val-pidtoword">pidToWord</a> : pid -&gt; SysWord.word

  val <a href="#val-fork">fork</a> : unit -&gt; pid option
  val <a href="#val-exec">exec</a> : string * string list -&gt; 'a
  val <a href="#val-exece">exece</a> : string * string list * string list -&gt; 'a
  val <a href="#val-execp">execp</a> : string * string list -&gt; 'a

  datatype <a href="#type-waitpid_arg">waitpid_arg</a>
    = <a href="#con-w_any_child">W_ANY_CHILD</a>
    | <a href="#con-w_child">W_CHILD</a> of pid
    | <a href="#con-w_same_group">W_SAME_GROUP</a>
    | <a href="#con-w_group">W_GROUP</a> of pid

  datatype <a href="#type-exit_status">exit_status</a>
    = <a href="#con-w_exited">W_EXITED</a>
    | <a href="#con-w_exitstatus">W_EXITSTATUS</a> of Word8.word
    | <a href="#con-w_signaled">W_SIGNALED</a> of signal
    | <a href="#con-w_stopped">W_STOPPED</a> of signal

  val <a href="#val-fromstatus">fromStatus</a> : OS.Process.status -&gt; exit_status

  structure <a href="#str-w">W</a> :
  sig
    include BIT_FLAGS
    val <a href="#val-w.untraced">untraced</a> : flags
  end

  val <a href="#val-wait">wait</a> : unit -&gt; pid * exit_status
  val <a href="#val-waitpid">waitpid</a> : waitpid_arg * W.flags list -&gt; pid * exit_status
  val <a href="#val-waitpid_nh">waitpid_nh</a> : waitpid_arg * W.flags list -&gt; (pid * exit_status) option

  val <a href="#val-exit">exit</a> : Word8.word -&gt; 'a

  datatype <a href="#type-killpid_arg">killpid_arg</a>
    = <a href="#con-k_proc">K_PROC</a> of pid
    | <a href="#con-k_same_group">K_SAME_GROUP</a>
    | <a href="#con-k_group">K_GROUP</a> of pid

  val <a href="#val-kill">kill</a> : killpid_arg * signal -&gt; unit

  val <a href="#val-alarm">alarm</a> : Time.time -&gt; Time.time
  val <a href="#val-pause">pause</a> : unit -&gt; unit
  val <a href="#val-sleep">sleep</a> : Time.time -&gt; Time.time
end
</pre>

### <a name="type-signal"></a>`signal`

```sml
eqtype signal
```

### <a name="type-pid"></a>`pid`

```sml
eqtype pid
```

### <a name="val-wordtopid"></a>`wordToPid`

```sml
val wordToPid : SysWord.word -> pid
```

<details><summary>Tests (1)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `no-validation`

</details>

### <a name="val-pidtoword"></a>`pidToWord`

```sml
val pidToWord : pid -> SysWord.word
```

<details><summary>Tests (2)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `wordToPid` &middot; `positive`

</details>

### <a name="val-fork"></a>`fork`

```sml
val fork : unit -> pid option
```

<details><summary>Tests (4)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `pid-of-child` &middot; `parent-keeps-pid` &middot; `child-is-a-copy` &middot; `child-changes-are-its-own`

</details>

### <a name="val-exec"></a>`exec`

```sml
val exec : string * string list -> 'a
```

<details><summary>Tests (7)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `status` &middot; `args` &middot; `argument-0` &middot; `same-process` &middot; `same-environment` &middot; `not-searched` &middot; `missing-file-raises`

</details>

### <a name="val-exece"></a>`exece`

```sml
val exece : string * string list * string list -> 'a
```

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `environment` &middot; `empty-environment` &middot; `missing-file-raises`

</details>

### <a name="val-execp"></a>`execp`

```sml
val execp : string * string list -> 'a
```

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `searched` &middot; `with-slash` &middot; `missing-raises`

</details>

### <a name="type-waitpid_arg"></a>`waitpid_arg`

```sml
datatype waitpid_arg
  = W_ANY_CHILD
  | W_CHILD of pid
  | W_SAME_GROUP
  | W_GROUP of pid
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-w_any_child"></a>`W_ANY_CHILD` |  |  |
| <a name="con-w_child"></a>`W_CHILD` | `pid` |  |
| <a name="con-w_same_group"></a>`W_SAME_GROUP` |  |  |
| <a name="con-w_group"></a>`W_GROUP` | `pid` |  |

### <a name="type-exit_status"></a>`exit_status`

```sml
datatype exit_status
  = W_EXITED
  | W_EXITSTATUS of Word8.word
  | W_SIGNALED of signal
  | W_STOPPED of signal
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-w_exited"></a>`W_EXITED` |  |  |
| <a name="con-w_exitstatus"></a>`W_EXITSTATUS` | `Word8.word` |  |
| <a name="con-w_signaled"></a>`W_SIGNALED` | `signal` |  |
| <a name="con-w_stopped"></a>`W_STOPPED` | `signal` |  |

### <a name="val-fromstatus"></a>`fromStatus`

```sml
val fromStatus : OS.Process.status -> exit_status
```

<details><summary>Tests (6)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `success` &middot; `failure` &middot; `system-exit-0` &middot; `system-exit-3` &middot; `system-exit-200` &middot; `system-killed`

</details>

### <a name="str-w"></a>`W`

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype |  |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val |  |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val |  |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val |  |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val |  |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val |  |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val |  |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val |  |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val |  |

#### <a name="val-w.untraced"></a>`untraced`

```sml
val untraced : flags
```

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `in-all` &middot; `nonempty` &middot; `waitpid-without-it`

</details>

### <a name="val-wait"></a>`wait`

```sml
val wait : unit -> pid * exit_status
```

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `child` &middot; `already-ended` &middot; `no-child` (raises)

</details>

### <a name="val-waitpid"></a>`waitpid`

```sml
val waitpid : waitpid_arg * W.flags list -> pid * exit_status
```

<details><summary>Tests (1)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `no-child` (raises)

</details>

### <a name="val-waitpid_nh"></a>`waitpid_nh`

```sml
val waitpid_nh : waitpid_arg * W.flags list -> (pid * exit_status) option
```

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `running-child` &middot; `ended-child` &middot; `no-child` (raises)

</details>

### <a name="val-exit"></a>`exit`

```sml
val exit : Word8.word -> 'a
```

<details><summary>Tests (5)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `status` &middot; `zero` &middot; `no-atExit` &middot; `no-flush` &middot; `result-has-any-type`

</details>

### <a name="type-killpid_arg"></a>`killpid_arg`

```sml
datatype killpid_arg
  = K_PROC of pid
  | K_SAME_GROUP
  | K_GROUP of pid
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-k_proc"></a>`K_PROC` | `pid` |  |
| <a name="con-k_same_group"></a>`K_SAME_GROUP` |  |  |
| <a name="con-k_group"></a>`K_GROUP` | `pid` |  |

### <a name="val-kill"></a>`kill`

```sml
val kill : killpid_arg * signal -> unit
```

<details><summary>Tests (2)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `term` &middot; `no-such-process` (raises)

</details>

### <a name="val-alarm"></a>`alarm`

```sml
val alarm : Time.time -> Time.time
```

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `none-outstanding` &middot; `remaining` &middot; `cancelled`

</details>

### <a name="val-pause"></a>`pause`

```sml
val pause : unit -> unit
```

<details><summary>Tests (2)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `until-alarm` &middot; `until-signal`

</details>

### <a name="val-sleep"></a>`sleep`

```sml
val sleep : Time.time -> Time.time
```

<details><summary>Tests (2)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `one-second` &middot; `zero`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_process.sml; do not edit.</sub>
