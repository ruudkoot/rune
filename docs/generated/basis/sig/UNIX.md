# signature UNIX

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **UNIX**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 14 of 14 entries documented |
| Tests | 32 checks of 11 entries |
| Source | [lib/basis/sig\_unix.sml](../../../../lib/basis/sig_unix.sml) |

## Synopsis

```sml
signature UNIX
structure Unix : UNIX where type exit_status = Posix.Process.exit_status where type signal = Posix.Signal.signal  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Unix`](../str/Unix.md) | Unix: running a program and talking to it through pipes. | [lib/basis/unix.sml](../../../../lib/basis/unix.sml) |

Running another program and talking to it: a child process with a pipe
each way.

[`execute`](#val-execute) starts a program and gives a [`proc`](#type-proc), from which the streams are
taken: what the child writes is read through [`textInstreamOf`](#val-textinstreamof), and what it
is to read is written through [`textOutstreamOf`](#val-textoutstreamof). [`reap`](#val-reap) waits for it and
is its status. This is [`Posix.Process`](../sig/POSIX.md#str-process)'s fork, exec and waitpid put
together, with the pipes made and the descriptors handed over; the
system starts the program itself, without a fork, which Windows does
not have.

The two type variables of [`proc`](#type-proc) say what its streams are, text or binary;
they are decided by which of the four functions is used on it, so a
top-level binding of a [`proc`](#type-proc) usually needs a type annotation, the value
restriction being what it is.

> **Erratum** `UNIX/opaque-in-the-page`. The page declares `structure Unix :> UNIX`, so [`signal`](#type-signal) is abstract there; the suite checks that it is
> [`Posix.Signal.signal`](../sig/POSIX_SIGNAL.md#type-signal) and that [`exit_status`](#type-exit_status) is
> [`Posix.Process.exit_status`](../sig/POSIX_PROCESS.md#type-exit_status), which the page requires where both structures
> exist

## Interface

<pre>
signature UNIX =
sig
  type ('a, 'b) <a href="#type-proc">proc</a>
  type <a href="#type-signal">signal</a>
  datatype <a href="#type-exit_status">exit_status</a>
    = <a href="#con-w_exited">W_EXITED</a>
    | <a href="#con-w_exitstatus">W_EXITSTATUS</a> of Word8.word
    | <a href="#con-w_signaled">W_SIGNALED</a> of signal
    | <a href="#con-w_stopped">W_STOPPED</a> of signal
  val <a href="#val-fromstatus">fromStatus</a> : OS.Process.status -&gt; exit_status
  val <a href="#val-executeinenv">executeInEnv</a> : string * string list * string list -&gt; ('a, 'b) proc
  val <a href="#val-execute">execute</a> : string * string list -&gt; ('a, 'b) proc
  val <a href="#val-textinstreamof">textInstreamOf</a> : (TextIO.instream, 'a) proc -&gt; TextIO.instream
  val <a href="#val-bininstreamof">binInstreamOf</a> : (BinIO.instream, 'a) proc -&gt; BinIO.instream
  val <a href="#val-textoutstreamof">textOutstreamOf</a> : ('a, TextIO.outstream) proc -&gt; TextIO.outstream
  val <a href="#val-binoutstreamof">binOutstreamOf</a> : ('a, BinIO.outstream) proc -&gt; BinIO.outstream
  val <a href="#val-streamsof">streamsOf</a> : (TextIO.instream, TextIO.outstream) proc -&gt; TextIO.instream * TextIO.outstream
  val <a href="#val-reap">reap</a> : ('a, 'b) proc -&gt; OS.Process.status
  val <a href="#val-kill">kill</a> : ('a, 'b) proc * signal -&gt; unit
  val <a href="#val-exit">exit</a> : Word8.word -&gt; 'a
end
</pre>

### <a name="type-proc"></a>`proc`

```sml
type ('a, 'b) proc
```

The type of a running child process, with the streams that talk to it.

The first type variable is the stream the child's output is read
through, the second the stream its input is written through.

### <a name="type-signal"></a>`signal`

```sml
type signal
```

The type of a signal, the one of [`Posix.Signal`](../sig/POSIX.md#str-signal).

### <a name="type-exit_status"></a>`exit_status`

```sml
datatype exit_status
  = W_EXITED
  | W_EXITSTATUS of Word8.word
  | W_SIGNALED of signal
  | W_STOPPED of signal
```

How a process ended, or why it stopped; the [`exit_status`](#type-exit_status) of [`Posix.Process`](../sig/POSIX.md#str-process).

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-w_exited"></a>`W_EXITED` |  | it ended of itself, successfully |
| <a name="con-w_exitstatus"></a>`W_EXITSTATUS` | `Word8.word` | it ended of itself, with that status |
| <a name="con-w_signaled"></a>`W_SIGNALED` | `signal` | a signal ended it |
| <a name="con-w_stopped"></a>`W_STOPPED` | `signal` | a signal stopped it; it has not ended |

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; Unix.fromStatus misreads the statuses that reap returns (exit 3 is W\_SIGNALED; a process that term ended is W\_SIGNALED of signal 1)
- **MLton** &mdash; Unix.fromStatus misreads the statuses that reap returns (exit 5 is W\_SIGNALED)

</details>

### <a name="val-fromstatus"></a>`fromStatus`

```sml
val fromStatus : OS.Process.status -> exit_status
```

`fromStatus st` is what the status `st` says about how the process ended.

<details><summary>Other implementations (1)</summary>

- **MLton, Poly/ML** &mdash; fromStatus OS.Process.failure is W\_SIGNALED, not W\_EXITSTATUS of a non-zero value

</details>

<details><summary>Tests (4)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `success` &middot; `failure` &middot; `system` &middot; `signaled`

</details>

### <a name="val-executeinenv"></a>`executeInEnv`

```sml
val executeInEnv : string * string list * string list -> ('a, 'b) proc
```

`executeInEnv (path, args, env)` starts the program at `path` with the arguments `args` and the environment `env`.

The child gets a pipe each way; the parent's ends are closed when it
runs another program, so a later child does not hold them open.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the child cannot be made.

> **Implementation** `Unix.executeInEnv/exec-failure-is-126`. A child whose
> `exec` fails ends with the status 126, as the page asks; that is what a
> [`reap`](#val-reap) of it reports, rather than an exception in the parent. On
> Windows, which starts a program without a child of this one's and
> knows at once that it cannot be run, this raises [`OS.SysErr`](../sig/OS.md#exn-syserr), which
> the page allows as well.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; a child that cannot execute the command exits with 1 (after reporting an uncaught SysErr), not 126

</details>

<details><summary>Tests (4)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `environment` &middot; `empty-environment` &middot; `arguments` &middot; `no-such-program`

</details>

### <a name="val-execute"></a>`execute`

```sml
val execute : string * string list -> ('a, 'b) proc
```

`execute (path, args)` is [`executeInEnv`](#val-executeinenv) with the environment this process has.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the child cannot be made.

> **Reading** `Unix.execute/current-directory`. The page does not say which
> directory the child runs in; it is this process's current one.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; a child that cannot execute the command exits with 1 (after reporting an uncaught SysErr), not 126

</details>

<details><summary>Tests (5)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `echo` &middot; `argument-list` &middot; `environment` &middot; `directory` &middot; `no-such-program`

</details>

### <a name="val-textinstreamof"></a>`textInstreamOf`

```sml
val textInstreamOf : (TextIO.instream, 'a) proc -> TextIO.instream
```

`textInstreamOf pr` is the text stream that what `pr` writes is read from.

<details><summary>Tests (1)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `lines`

</details>

### <a name="val-bininstreamof"></a>`binInstreamOf`

```sml
val binInstreamOf : (BinIO.instream, 'a) proc -> BinIO.instream
```

`binInstreamOf pr` is the binary stream that what `pr` writes is read from.

<details><summary>Tests (1)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `bytes`

</details>

### <a name="val-textoutstreamof"></a>`textOutstreamOf`

```sml
val textOutstreamOf : ('a, TextIO.outstream) proc -> TextIO.outstream
```

`textOutstreamOf pr` is the text stream that `pr` reads what is written to it from.

<details><summary>Tests (1)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `to-cat`

</details>

### <a name="val-binoutstreamof"></a>`binOutstreamOf`

```sml
val binOutstreamOf : ('a, BinIO.outstream) proc -> BinIO.outstream
```

`binOutstreamOf pr` is the binary stream that `pr` reads what is written to it from.

<details><summary>Tests (2)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `to-cat` &middot; `text-back`

</details>

### <a name="val-streamsof"></a>`streamsOf`

```sml
val streamsOf : (TextIO.instream, TextIO.outstream) proc -> TextIO.instream * TextIO.outstream
```

`streamsOf pr` is the pair of the text streams of `pr`.

<details><summary>Tests (1)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `conversation`

</details>

### <a name="val-reap"></a>`reap`

```sml
val reap : ('a, 'b) proc -> OS.Process.status
```

`reap pr` closes the streams of `pr`, waits for it to end, and is its status.

> **Reading** `Unix.reap/status-is-remembered`. The status is kept, so
> reaping the same process again gives the same answer rather than
> failing. A child that is merely stopped does not end the wait, since
> [`Posix.Process.W.untraced`](../sig/POSIX_PROCESS.md#val-w.untraced) is not asked for.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the wait fails.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; Unix.fromStatus misreads the statuses that reap returns (exit 3 is W\_SIGNALED; a process that term ended is W\_SIGNALED of signal 1)

</details>

<details><summary>Tests (7)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `success` &middot; `failure` &middot; `status` &middot; `twice` &middot; `twice-same-status` &middot; `closes-input` &middot; `waits`

</details>

### <a name="val-kill"></a>`kill`

```sml
val kill : ('a, 'b) proc * signal -> unit
```

`kill (pr, s)` sends the signal `s` to the child `pr`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the signal may not be sent.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; Unix.fromStatus misreads the statuses that reap returns (a process that term or kill ended is W\_SIGNALED of signal 1)

</details>

<details><summary>Tests (2)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `term` &middot; `kill`

</details>

### <a name="val-exit"></a>`exit`

```sml
val exit : Word8.word -> 'a
```

`exit st` ends this program with the status `st`.

> **Reading** `Unix.exit/flushes`. It runs the [`OS.Process.atExit`](../sig/OS_PROCESS.md#val-atexit) actions
> and then leaves through the VM's exit, which flushes every file; that is
> taken to satisfy "flushes and closes all I/O streams".

<details><summary>Other implementations (3)</summary>

- **SML/NJ** &mdash; Unix.exit does not flush the output streams that are open
- **Poly/ML 5.9.2** &mdash; a forked child that calls Unix.exit never ends
- **SML/NJ** &mdash; Unix.exit does not run the actions of OS.Process.atExit

</details>

<details><summary>Tests (4)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `status` &middot; `flushes` &middot; `runs-atExit` &middot; `result-has-any-type`

</details>

## See also

[`POSIX_PROCESS`](../sig/POSIX_PROCESS.md), [`OS_PROCESS`](../sig/OS_PROCESS.md), [`TEXT_IO`](../sig/TEXT_IO.md), [`BIN_IO`](../sig/BIN_IO.md), [`POSIX`](../sig/POSIX.md)

---

<sub>Generated by runedoc from lib/basis/sig\_unix.sml; do not edit.</sub>
