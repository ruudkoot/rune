# signature UNIX

[The Standard ML Basis Library](../README.md) &rsaquo; **UNIX**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 14 entries documented |
| Tests | 32 checks of 11 entries |
| Source | [lib/basis/sig\_unix.sml](../../../../lib/basis/sig_unix.sml) |

## Synopsis

```sml
signature UNIX
structure Unix : UNIX  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Unix` | Unix: running a program and talking to it through pipes. | [lib/basis/unix.sml](../../../../lib/basis/unix.sml) |

signature UNIX, transcribed from <https://smlfamily.github.io/Basis/unix.html>

The page declares `structure Unix :> UNIX`: signal is abstract there, and
whether it is Posix.Signal.signal and exit\_status is
Posix.Process.exit\_status (which the page requires when both structures
exist) is checked in tests/basis/unix\_sig.sml.

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

### <a name="type-signal"></a>`signal`

```sml
type signal
```

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

<details><summary>Tests (4)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `success` &middot; `failure` &middot; `system` &middot; `signaled`

</details>

### <a name="val-executeinenv"></a>`executeInEnv`

```sml
val executeInEnv : string * string list * string list -> ('a, 'b) proc
```

<details><summary>Tests (4)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `environment` &middot; `empty-environment` &middot; `arguments` &middot; `no-such-program`

</details>

### <a name="val-execute"></a>`execute`

```sml
val execute : string * string list -> ('a, 'b) proc
```

<details><summary>Tests (5)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `echo` &middot; `argument-list` &middot; `environment` &middot; `directory` &middot; `no-such-program`

</details>

### <a name="val-textinstreamof"></a>`textInstreamOf`

```sml
val textInstreamOf : (TextIO.instream, 'a) proc -> TextIO.instream
```

<details><summary>Tests (1)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `lines`

</details>

### <a name="val-bininstreamof"></a>`binInstreamOf`

```sml
val binInstreamOf : (BinIO.instream, 'a) proc -> BinIO.instream
```

<details><summary>Tests (1)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `bytes`

</details>

### <a name="val-textoutstreamof"></a>`textOutstreamOf`

```sml
val textOutstreamOf : ('a, TextIO.outstream) proc -> TextIO.outstream
```

<details><summary>Tests (1)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `to-cat`

</details>

### <a name="val-binoutstreamof"></a>`binOutstreamOf`

```sml
val binOutstreamOf : ('a, BinIO.outstream) proc -> BinIO.outstream
```

<details><summary>Tests (2)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `to-cat` &middot; `text-back`

</details>

### <a name="val-streamsof"></a>`streamsOf`

```sml
val streamsOf : (TextIO.instream, TextIO.outstream) proc -> TextIO.instream * TextIO.outstream
```

<details><summary>Tests (1)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `conversation`

</details>

### <a name="val-reap"></a>`reap`

```sml
val reap : ('a, 'b) proc -> OS.Process.status
```

<details><summary>Tests (7)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `success` &middot; `failure` &middot; `status` &middot; `twice` &middot; `twice-same-status` &middot; `closes-input` &middot; `waits`

</details>

### <a name="val-kill"></a>`kill`

```sml
val kill : ('a, 'b) proc * signal -> unit
```

<details><summary>Tests (2)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `term` &middot; `kill`

</details>

### <a name="val-exit"></a>`exit`

```sml
val exit : Word8.word -> 'a
```

<details><summary>Tests (4)</summary>

For `Unix`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `status` &middot; `flushes` &middot; `runs-atExit` &middot; `result-has-any-type`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_unix.sml; do not edit.</sub>
