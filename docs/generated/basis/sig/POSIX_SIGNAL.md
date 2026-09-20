# signature POSIX_SIGNAL

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **POSIX_SIGNAL**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 23 of 23 entries documented |
| Tests | 34 checks of 22 entries |
| Source | [lib/basis/sig\_posix\_signal.sml](../../../../lib/basis/sig_posix_signal.sml) |

## Synopsis

```sml
signature POSIX_SIGNAL
structure Posix.Signal : POSIX_SIGNAL  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.Signal` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

The signals a process may be sent, by name.

A signal is a number that the system uses to interrupt a process:
[`Posix.Process.kill`](../sig/POSIX_PROCESS.md#val-kill) sends one, [`Unix.kill`](../sig/UNIX.md#val-kill) sends one to a child, and
[`Posix.Process.fromStatus`](../sig/POSIX_PROCESS.md#val-fromstatus) reports the one that ended a process. The names
below are the signals POSIX prescribes; [`fromWord`](#val-fromword) reaches the others.

Nothing here installs a handler: this signature names signals, it does not
catch them.

> **Implementation** `Posix.Signal/numbers-are-the-systems`. A signal is the
> number the system gives it, which differs from system to system; the suite
> checks each name against what the shell's `kill -l` calls that number.
> Signals that would dump core, stop the process or be ignored by the runner
> are checked by number only and never sent.

## Contents

[The signals POSIX names](#the-signals-posix-names)

## Interface

<pre>
signature POSIX_SIGNAL =
sig
  eqtype <a href="#type-signal">signal</a>

  val <a href="#val-toword">toWord</a> : signal -&gt; SysWord.word

  val <a href="#val-fromword">fromWord</a> : SysWord.word -&gt; signal

  val <a href="#val-abrt">abrt</a> : signal

  val <a href="#val-alrm">alrm</a> : signal

  val <a href="#val-bus">bus</a> : signal

  val <a href="#val-fpe">fpe</a> : signal

  val <a href="#val-hup">hup</a> : signal

  val <a href="#val-ill">ill</a> : signal

  val <a href="#val-int">int</a> : signal

  val <a href="#val-kill">kill</a> : signal

  val <a href="#val-pipe">pipe</a> : signal

  val <a href="#val-quit">quit</a> : signal

  val <a href="#val-segv">segv</a> : signal

  val <a href="#val-term">term</a> : signal

  val <a href="#val-usr1">usr1</a> : signal

  val <a href="#val-usr2">usr2</a> : signal

  val <a href="#val-chld">chld</a> : signal

  val <a href="#val-cont">cont</a> : signal

  val <a href="#val-stop">stop</a> : signal

  val <a href="#val-tstp">tstp</a> : signal

  val <a href="#val-ttin">ttin</a> : signal

  val <a href="#val-ttou">ttou</a> : signal
end
</pre>

### <a name="type-signal"></a>`signal`

```sml
eqtype signal
```

The type of a signal.

Two are equal when they are the same signal.

### <a name="val-toword"></a>`toWord`

```sml
val toWord : signal -> SysWord.word
```

`toWord s` is the number the system gives `s`.

**Example** `toWord kill = 0w9`

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `distinct`

</details>

### <a name="val-fromword"></a>`fromWord`

```sml
val fromWord : SysWord.word -> signal
```

`fromWord w` is the signal numbered `w`, which need not be one named here.

**Example** `fromWord 0w15 = term`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; fromWord keeps every bit of its argument, also those not in all, so that toWord o fromWord is not fn w =\> SysWord.andb (w, toWord all) and fromWord makes flags outside all

</details>

<details><summary>Tests (3)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `of-toWord-all` &middot; `no-check` &middot; `equal-words-equal-signals`

</details>

## The signals POSIX names

### <a name="val-abrt"></a>`abrt`

```sml
val abrt : signal
```

Abort: the process ended itself, as `abort` does.

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-alrm"></a>`alrm`

```sml
val alrm : signal
```

The alarm set by [`Posix.Process.alarm`](../sig/POSIX_PROCESS.md#val-alarm) has gone off.

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-bus"></a>`bus`

```sml
val bus : signal
```

A memory access the hardware refused.

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-fpe"></a>`fpe`

```sml
val fpe : signal
```

An arithmetic fault, such as a division by zero.

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-hup"></a>`hup`

```sml
val hup : signal
```

The terminal the process was attached to has gone.

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-ill"></a>`ill`

```sml
val ill : signal
```

The processor met an instruction it cannot run.

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-int"></a>`int`

```sml
val int : signal
```

The interrupt character was typed, usually control-C.

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-kill"></a>`kill`

```sml
val kill : signal
```

End the process; it cannot be caught, blocked or ignored.

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-pipe"></a>`pipe`

```sml
val pipe : signal
```

A pipe or a socket was written that nobody reads.

**See also** [`POSIX_ERROR`](../sig/POSIX_ERROR.md)

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; the runtime ignores SIGPIPE, and the programs it executes inherit that

</details>

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-quit"></a>`quit`

```sml
val quit : signal
```

The quit character was typed, usually control-backslash.

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-segv"></a>`segv`

```sml
val segv : signal
```

The process touched memory that is not its own.

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-term"></a>`term`

```sml
val term : signal
```

Ask the process to end; the polite one, which may be caught.

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-usr1"></a>`usr1`

```sml
val usr1 : signal
```

A signal with no meaning of its own, for a program to use.

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-usr2"></a>`usr2`

```sml
val usr2 : signal
```

A second signal with no meaning of its own.

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-chld"></a>`chld`

```sml
val chld : signal
```

A child has stopped or ended.

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ignored-by-default`

</details>

### <a name="val-cont"></a>`cont`

```sml
val cont : signal
```

Carry on after having been stopped.

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `continues`

</details>

### <a name="val-stop"></a>`stop`

```sml
val stop : signal
```

Stop the process; it cannot be caught, blocked or ignored.

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `stops-shell`

</details>

### <a name="val-tstp"></a>`tstp`

```sml
val tstp : signal
```

Stop the process, from the terminal; usually control-Z.

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-ttin"></a>`ttin`

```sml
val ttin : signal
```

A background process tried to read from the terminal.

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-ttou"></a>`ttou`

```sml
val ttou : signal
```

A background process tried to write to the terminal.

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

## See also

[`POSIX_PROCESS`](../sig/POSIX_PROCESS.md), [`UNIX`](../sig/UNIX.md), [`POSIX`](../sig/POSIX.md)

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_signal.sml; do not edit.</sub>
