# signature PTY

[The Standard ML Basis Library](../README.md) &rsaquo; The runtime &rsaquo; **PTY**

|  |  |
| --- | --- |
| Status | extension |
| Implementations | 1 |
| Documentation | 8 of 8 entries documented |
| Tests | 7 checks of 7 entries |
| Source | [lib/basis/pty\_sig.sml](../../../../lib/basis/pty_sig.sml) |

## Synopsis

```sml
signature PTY
structure Pty : PTY  (* extension *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Pty`](../str/Pty.md) | Pseudo-terminal ownership over the system-layer PTY operations. | [lib/basis/pty.sml](../../../../lib/basis/pty.sml) |

A child attached to a new pseudo-terminal, independent of any terminal
emulator program. POSIX supplies a controlling terminal and session;
Windows supplies ConPTY. The session owns its descriptors; callers own
waiting for its child. This interface is Rune's extension.

## Interface

<pre>
signature PTY =
sig
  type <a href="#type-session">session</a>
  exception <a href="#exn-closed">Closed</a>
  val <a href="#val-spawn">spawn</a> : {<a href="#fld-spawn.program">program</a> : string, <a href="#fld-spawn.args">args</a> : string list, <a href="#fld-spawn.env">env</a> : string list option,
               <a href="#fld-spawn.dir">dir</a> : string option, <a href="#fld-spawn.columns">columns</a> : int, <a href="#fld-spawn.rows">rows</a> : int} -&gt; session
  val <a href="#val-input">input</a> : session -&gt; int
  val <a href="#val-output">output</a> : session -&gt; int
  val <a href="#val-process">process</a> : session -&gt; Subprocess.pid
  val <a href="#val-resize">resize</a> : session * {<a href="#fld-resize.columns">columns</a> : int, <a href="#fld-resize.rows">rows</a> : int} -&gt; unit
  val <a href="#val-close">close</a> : session -&gt; unit
end
</pre>

### <a name="type-session"></a>`session`

```sml
type session
```

An owned terminal and the child attached to it.

### <a name="exn-closed"></a>`Closed`

```sml
exception Closed
```

What borrowing or resizing a closed session raises.

<details><summary>Tests (1)</summary>

For `Pty`, in [tests/basis/pty.sml](../../../../tests/basis/pty.sml): `input-after-close`

</details>

### <a name="val-spawn"></a>`spawn`

```sml
val spawn : {program : string, args : string list, env : string list option,
             dir : string option, columns : int, rows : int} -> session
```

`spawn settings` starts a child on the terminal that settings describes.

args includes argv\[0\].
NONE environment or directory inherits the parent's. Dimensions outside
1\..32767 raise Domain. OS.SysErr reports an unavailable terminal backend
(ENOSYS for sys\_none and Windows without ConPTY). POSIX exec failure is
a child exiting with 126, as with Subprocess.spawn.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-spawn.program"></a>`program` | `string` |  |
| <a name="fld-spawn.args"></a>`args` | `string list` |  |
| <a name="fld-spawn.env"></a>`env` | `string list option` |  |
| <a name="fld-spawn.dir"></a>`dir` | `string option` |  |
| <a name="fld-spawn.columns"></a>`columns` | `int` |  |
| <a name="fld-spawn.rows"></a>`rows` | `int` |  |

<details><summary>Tests (1)</summary>

For `Pty`, in [tests/basis/pty.sml](../../../../tests/basis/pty.sml): `dimensions`

</details>

### <a name="val-input"></a>`input`

```sml
val input : session -> int
```

`input s` is the borrowed numeric descriptor for reading terminal output.

Convert with Posix.FileSys.wordToFD o SysWord.fromInt to read/write or
poll them. They must not be closed independently. Numeric descriptors
keep this extension independent of Posix's abstract client types.

<details><summary>Tests (1)</summary>

For `Pty`, in [tests/basis/pty.sml](../../../../tests/basis/pty.sml): `borrowed-number`

</details>

### <a name="val-output"></a>`output`

```sml
val output : session -> int
```

`output s` is the borrowed descriptor that writes input to the terminal.
Convert its number as for input; never close it independently.

<details><summary>Tests (1)</summary>

For `Pty`, in [tests/basis/pty.sml](../../../../tests/basis/pty.sml): `borrowed-number`

</details>

### <a name="val-process"></a>`process`

```sml
val process : session -> Subprocess.pid
```

`process s` is the child, waited for with Subprocess.wait/poll, including
after close.

<details><summary>Tests (1)</summary>

For `Pty`, in [tests/basis/pty.sml](../../../../tests/basis/pty.sml): `ordinary-child`

</details>

### <a name="val-resize"></a>`resize`

```sml
val resize : session * {columns : int, rows : int} -> unit
```

`resize (s, size)` changes the terminal dimensions and notifies its foreground program.

Raises Domain for
dimensions outside 1..32767, Closed after close, OS.SysErr on failure.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-resize.columns"></a>`columns` | `int` |  |
| <a name="fld-resize.rows"></a>`rows` | `int` |  |

<details><summary>Tests (1)</summary>

For `Pty`, in [tests/basis/pty.sml](../../../../tests/basis/pty.sml): `new-window`

</details>

### <a name="val-close"></a>`close`

```sml
val close : session -> unit
```

`close s` disconnects the terminal and discards unread output.

Attached programs may end. Reap the child separately. Idempotent; input/output/resize then
raise Closed. A session is an external resource: close it explicitly,
and do not expect it to survive saved-image restoration.

<details><summary>Tests (1)</summary>

For `Pty`, in [tests/basis/pty.sml](../../../../tests/basis/pty.sml): `idempotent`

</details>

---

<sub>Generated by runedoc from lib/basis/pty\_sig.sml; do not edit.</sub>
