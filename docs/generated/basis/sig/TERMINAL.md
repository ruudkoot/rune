# signature TERMINAL

[The Standard ML Basis Library](../README.md) &rsaquo; The runtime &rsaquo; **TERMINAL**

|  |  |
| --- | --- |
| Status | extension |
| Implementations | 1 |
| Documentation | 6 of 6 entries documented |
| Tests | 7 checks of 6 entries |
| Source | [lib/basis/terminal\_sig.sml](../../../../lib/basis/terminal_sig.sml) |

## Synopsis

```sml
signature TERMINAL
structure Terminal : TERMINAL  (* extension *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Terminal`](../str/Terminal.md) | Terminal: the terminal of a program that edits what is typed at it, over the runtime's term\_size, term\_resizes, term\_enter, term\_leave and term\_read (runtime/sys/sys.h). It is Rune's own and not of the specification. | [lib/basis/terminal.sml](../../../../lib/basis/terminal.sml) |

The terminal of a program that edits what is typed at it, as a line
editor does: the window's size and its changes, keys read one by one
with a time limit, and a terminal put back as it was whatever way the
program ends (docs/plans/repl.md, D4 and D5).

The terminal is the process's own: keys are read from the standard
input and the program draws on the standard output. [`Posix.TTY`](../str/Posix.TTY.md) sets a
terminal's modes too, but where this structure differs is in what the
runtime does beside: it puts the terminal back at exit, at a fatal
error and at a signal that ends the process, which a program cannot
do for itself; it counts the window's changes of size (`SIGWINCH`); and
on Windows it reads the console's records, with the console making the
same bytes of each key that a terminal of Unix sends, so that a program
decodes one language of keys everywhere. `lib/terminal` is built on it.

What [`TextIO.stdIn`](../sig/TEXT_IO.md#val-stdin) has read ahead into its buffer is not seen by
[`read`](#val-read): a program reads its terminal with one or the other while it is
raw.

> **Deviation** `TERMINAL/not-in-the-specification`. The specification
> has [`Posix.TTY`](../str/Posix.TTY.md) for a terminal's modes and nothing for a window's size,
> a key read with a time limit or a console of Windows; this signature is
> Rune's alone, and a program that uses it does not port.

## Interface

<pre>
signature TERMINAL =
sig
  val <a href="#val-size">size</a> : unit -&gt; {<a href="#fld-size.columns">columns</a> : int, <a href="#fld-size.rows">rows</a> : int} option
  val <a href="#val-resizes">resizes</a> : unit -&gt; int
  val <a href="#val-enter">enter</a> : {<a href="#fld-enter.undo">undo</a> : string} -&gt; unit
  val <a href="#val-quiet">quiet</a> : unit -&gt; unit
  val <a href="#val-leave">leave</a> : unit -&gt; unit
  val <a href="#val-read">read</a> : Time.time option -&gt; string option
end
</pre>

### <a name="val-size"></a>`size`

```sml
val size : unit -> {columns : int, rows : int} option
```

`size ()` is the columns and rows of the terminal's window, or `NONE`
when no standard stream is a terminal.

The terminal is the standard output's, or, when that is not one, the
standard input's or error's. A terminal that does not know its size
says 0 for both.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-size.columns"></a>`columns` | `int` |  |
| <a name="fld-size.rows"></a>`rows` | `int` |  |

<details><summary>Tests (1)</summary>

For `Terminal`, in [tests/basis/terminal.sml](../../../../tests/basis/terminal.sml): `none-without-a-terminal`

</details>

### <a name="val-resizes"></a>`resizes`

```sml
val resizes : unit -> int
```

`resizes ()` is how many times the window has changed its size since
the first call of [`resizes`](#val-resizes), which starts the count.

A program asks it before it draws and draws the whole screen again
when it has grown. On Windows the changes are seen by [`read`](#val-read), while
the terminal is raw. `~1` where the system cannot count them.

<details><summary>Tests (1)</summary>

For `Terminal`, in [tests/basis/terminal.sml](../../../../tests/basis/terminal.sml): `counted-from-zero`

</details>

### <a name="val-enter"></a>`enter`

```sml
val enter : {undo : string} -> unit
```

`enter {undo}` puts the terminal of the standard input in raw mode,
which the runtime undoes however the program ends.

Raw is each byte as it is typed, nothing echoed, no signal from a key
\-- Ctrl-C is the byte 3 -- and the output still translated, a newline
written as a carriage return and a newline. On Windows the console
makes each key the bytes a terminal of Unix sends, in UTF-8.

`undo` is what to write to the standard output to take back what the
program turned on itself with escapes (bracketed paste, a hidden
cursor): it is written when the terminal is put back, by [`leave`](#val-leave) or by
the runtime. The runtime puts the terminal back at exit, at a fatal
error, at `SIGTERM`, `SIGHUP` and `SIGQUIT`, and on a stop (`SIGTSTP`),
making it raw again when the process is continued and counting that
as a resize, since the screen may have changed meanwhile.

What the terminal was is kept from the first call, so a program can
enter and leave as often as it likes; to enter while raw changes
`undo`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) when the standard input is not a terminal, or a
console of Windows refuses VT input (before Windows 10 1511, or the
legacy console), or `undo` is longer than 256 bytes.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-enter.undo"></a>`undo` | `string` |  |

<details><summary>Tests (2)</summary>

For `Terminal`, in [tests/basis/terminal.sml](../../../../tests/basis/terminal.sml): `refused-without-a-terminal` (raises) &middot; `refused-without-a-terminal-whatever-the-undo` (raises)

</details>

### <a name="val-quiet"></a>`quiet`

```sml
val quiet : unit -> unit
```

`quiet ()` puts the terminal of the standard input in quiet mode,
for while a program runs that the user may interrupt.

Quiet is nothing echoed and lines not edited, so that keys typed
ahead stay unseen until a program reads them, while a key still makes
its signal: Ctrl-C is the user's interrupt ([`Runtime`](../str/Runtime.md)). The runtime
puts the terminal back from quiet mode as it does from raw mode, and
[`enter`](#val-enter) and [`quiet`](#val-quiet) go from one to the other; [`quiet`](#val-quiet) has no `undo`.
The REPL holds the terminal quiet while what it compiled runs
(docs/repl.md).

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) as [`enter`](#val-enter) does.

<details><summary>Tests (1)</summary>

For `Terminal`, in [tests/basis/terminal.sml](../../../../tests/basis/terminal.sml): `refused-without-a-terminal` (raises)

</details>

### <a name="val-leave"></a>`leave`

```sml
val leave : unit -> unit
```

`leave ()` puts the terminal back as it was before [`enter`](#val-enter) or [`quiet`](#val-quiet),
writing `undo`; nothing when it is neither raw nor quiet.

<details><summary>Tests (1)</summary>

For `Terminal`, in [tests/basis/terminal.sml](../../../../tests/basis/terminal.sml): `nothing-when-not-raw`

</details>

### <a name="val-read"></a>`read`

```sml
val read : Time.time option -> string option
```

`read wait` is the bytes typed at the terminal since the last [`read`](#val-read),
waiting for them at most `wait` (`NONE`: as long as it takes).

It is `SOME ""` when the time is up or a resize ended the wait, and
`NONE` at the end of the input. A key can arrive in two reads; the
bytes are those the terminal sent, so a key is decoded from what the
reads gave, not from one read.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) when the standard input is not a terminal, or the
read fails. The user's interrupt, where the program catches it
([`Runtime`](../str/Runtime.md)), is raised where it ends the wait.

<details><summary>Tests (1)</summary>

For `Terminal`, in [tests/basis/terminal.sml](../../../../tests/basis/terminal.sml): `refused-without-a-terminal` (raises)

</details>

## See also

[`POSIX_TTY`](../sig/POSIX_TTY.md), [`RUNTIME`](../sig/RUNTIME.md)

---

<sub>Generated by runedoc from lib/basis/terminal\_sig.sml; do not edit.</sub>
