# signature POSIX_TTY

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **POSIX_TTY**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 110 of 110 entries documented |
| Tests | 115 checks of 97 entries |
| Source | [lib/basis/sig\_posix\_tty.sml](../../../../lib/basis/sig_posix_tty.sml) |

## Synopsis

```sml
signature POSIX_TTY
structure Posix.TTY : POSIX_TTY  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.TTY` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

Terminals: their modes, their speeds and the characters that control them.

What a terminal does with what is typed at it and with what is written to
it is held in a [`termios`](#val-termios): four sets of flags, an array of control
characters, and two speeds. [`TC.getattr`](#val-tc.getattr) reads the settings of a
descriptor, [`TC.setattr`](#val-tc.setattr) writes them back, and everything in between is
how a [`termios`](#val-termios) is taken apart and put together.

The four sets of flags are [`I`](#str-i) for what is done to input, [`O`](#str-o) for what is
done to output, [`C`](#str-c) for the line itself, and [`L`](#str-l) for how the terminal
treats the program -- whether it echoes, whether it waits for a whole line
([`L.icanon`](#val-l.icanon)), whether typing the interrupt character sends a signal
([`L.isig`](#val-l.isig)). Turning [`L.icanon`](#val-l.icanon) and [`L.echo`](#val-l.echo) off is what a program does to
read keys as they are typed.

[`V`](#str-v) names the positions in the array of control characters: which
character means end of file, which interrupts, which erases.

> **Erratum** `POSIX_TTY/flexible-types`. The types [`pid`](#type-pid) and [`file_desc`](#type-file_desc) are
> left flexible here, as on the page; [`POSIX`](../sig/POSIX.md) fixes them.

> **Implementation** `Posix.TTY/what-the-values-are`. A set of flags is a
> `tcflag_t` word of the system, a speed is its `speed_t`, and the control
> characters are a string of [`V.nccs`](#val-v.nccs) characters; all of them are read and
> written in one call.

## Interface

<pre>
signature POSIX_TTY =
sig
  eqtype <a href="#type-pid">pid</a>

  eqtype <a href="#type-file_desc">file_desc</a>

  structure <a href="#str-v">V</a> :
  sig
    val <a href="#val-v.eof">eof</a> : int

    val <a href="#val-v.eol">eol</a> : int

    val <a href="#val-v.erase">erase</a> : int

    val <a href="#val-v.intr">intr</a> : int

    val <a href="#val-v.kill">kill</a> : int

    val <a href="#val-v.min">min</a> : int

    val <a href="#val-v.quit">quit</a> : int

    val <a href="#val-v.susp">susp</a> : int

    val <a href="#val-v.time">time</a> : int

    val <a href="#val-v.start">start</a> : int

    val <a href="#val-v.stop">stop</a> : int

    val <a href="#val-v.nccs">nccs</a> : int

    type <a href="#type-v.cc">cc</a>

    val <a href="#val-v.cc">cc</a> : (int * char) list -&gt; cc

    val <a href="#val-v.update">update</a> : cc * (int * char) list -&gt; cc

    val <a href="#val-v.sub">sub</a> : cc * int -&gt; char
  end

  structure <a href="#str-i">I</a> :
  sig
    include BIT_FLAGS

    val <a href="#val-i.brkint">brkint</a> : flags

    val <a href="#val-i.icrnl">icrnl</a> : flags

    val <a href="#val-i.ignbrk">ignbrk</a> : flags

    val <a href="#val-i.igncr">igncr</a> : flags

    val <a href="#val-i.ignpar">ignpar</a> : flags

    val <a href="#val-i.inlcr">inlcr</a> : flags

    val <a href="#val-i.inpck">inpck</a> : flags

    val <a href="#val-i.istrip">istrip</a> : flags

    val <a href="#val-i.ixoff">ixoff</a> : flags

    val <a href="#val-i.ixon">ixon</a> : flags

    val <a href="#val-i.parmrk">parmrk</a> : flags
  end

  structure <a href="#str-o">O</a> :
  sig
    include BIT_FLAGS

    val <a href="#val-o.opost">opost</a> : flags
  end

  structure <a href="#str-c">C</a> :
  sig
    include BIT_FLAGS

    val <a href="#val-c.clocal">clocal</a> : flags

    val <a href="#val-c.cread">cread</a> : flags

    val <a href="#val-c.cs5">cs5</a> : flags

    val <a href="#val-c.cs6">cs6</a> : flags

    val <a href="#val-c.cs7">cs7</a> : flags

    val <a href="#val-c.cs8">cs8</a> : flags

    val <a href="#val-c.csize">csize</a> : flags

    val <a href="#val-c.cstopb">cstopb</a> : flags

    val <a href="#val-c.hupcl">hupcl</a> : flags

    val <a href="#val-c.parenb">parenb</a> : flags

    val <a href="#val-c.parodd">parodd</a> : flags
  end

  structure <a href="#str-l">L</a> :
  sig
    include BIT_FLAGS

    val <a href="#val-l.echo">echo</a> : flags

    val <a href="#val-l.echoe">echoe</a> : flags

    val <a href="#val-l.echok">echok</a> : flags

    val <a href="#val-l.echonl">echonl</a> : flags

    val <a href="#val-l.icanon">icanon</a> : flags

    val <a href="#val-l.iexten">iexten</a> : flags

    val <a href="#val-l.isig">isig</a> : flags

    val <a href="#val-l.noflsh">noflsh</a> : flags

    val <a href="#val-l.tostop">tostop</a> : flags
  end

  eqtype <a href="#type-speed">speed</a>

  val <a href="#val-comparespeed">compareSpeed</a> : speed * speed -&gt; order

  val <a href="#val-speedtoword">speedToWord</a> : speed -&gt; SysWord.word

  val <a href="#val-wordtospeed">wordToSpeed</a> : SysWord.word -&gt; speed

  val <a href="#val-b0">b0</a> : speed

  val <a href="#val-b50">b50</a> : speed

  val <a href="#val-b75">b75</a> : speed

  val <a href="#val-b110">b110</a> : speed

  val <a href="#val-b134">b134</a> : speed

  val <a href="#val-b150">b150</a> : speed

  val <a href="#val-b200">b200</a> : speed

  val <a href="#val-b300">b300</a> : speed

  val <a href="#val-b600">b600</a> : speed

  val <a href="#val-b1200">b1200</a> : speed

  val <a href="#val-b1800">b1800</a> : speed

  val <a href="#val-b2400">b2400</a> : speed

  val <a href="#val-b4800">b4800</a> : speed

  val <a href="#val-b9600">b9600</a> : speed

  val <a href="#val-b19200">b19200</a> : speed

  val <a href="#val-b38400">b38400</a> : speed

  type <a href="#type-termios">termios</a>

  val <a href="#val-termios">termios</a> : {<a href="#fld-termios.iflag">iflag</a> : I.flags,
                 <a href="#fld-termios.oflag">oflag</a> : O.flags,
                 <a href="#fld-termios.cflag">cflag</a> : C.flags,
                 <a href="#fld-termios.lflag">lflag</a> : L.flags,
                 <a href="#fld-termios.cc">cc</a> : V.cc,
                 <a href="#fld-termios.ispeed">ispeed</a> : speed,
                 <a href="#fld-termios.ospeed">ospeed</a> : speed}
                -&gt; termios

  val <a href="#val-fieldsof">fieldsOf</a> : termios
                 -&gt; {<a href="#fld-fieldsof.iflag">iflag</a> : I.flags,
                     <a href="#fld-fieldsof.oflag">oflag</a> : O.flags,
                     <a href="#fld-fieldsof.cflag">cflag</a> : C.flags,
                     <a href="#fld-fieldsof.lflag">lflag</a> : L.flags,
                     <a href="#fld-fieldsof.cc">cc</a> : V.cc,
                     <a href="#fld-fieldsof.ispeed">ispeed</a> : speed,
                     <a href="#fld-fieldsof.ospeed">ospeed</a> : speed}

  val <a href="#val-getiflag">getiflag</a> : termios -&gt; I.flags

  val <a href="#val-getoflag">getoflag</a> : termios -&gt; O.flags

  val <a href="#val-getcflag">getcflag</a> : termios -&gt; C.flags

  val <a href="#val-getlflag">getlflag</a> : termios -&gt; L.flags

  val <a href="#val-getcc">getcc</a> : termios -&gt; V.cc

  structure <a href="#str-cf">CF</a> :
  sig
    val <a href="#val-cf.getospeed">getospeed</a> : termios -&gt; speed

    val <a href="#val-cf.getispeed">getispeed</a> : termios -&gt; speed

    val <a href="#val-cf.setospeed">setospeed</a> : termios * speed -&gt; termios

    val <a href="#val-cf.setispeed">setispeed</a> : termios * speed -&gt; termios
  end

  structure <a href="#str-tc">TC</a> :
  sig
    eqtype <a href="#type-tc.set_action">set_action</a>

    val <a href="#val-tc.sanow">sanow</a> : set_action

    val <a href="#val-tc.sadrain">sadrain</a> : set_action

    val <a href="#val-tc.saflush">saflush</a> : set_action

    eqtype <a href="#type-tc.flow_action">flow_action</a>

    val <a href="#val-tc.ooff">ooff</a> : flow_action

    val <a href="#val-tc.oon">oon</a> : flow_action

    val <a href="#val-tc.ioff">ioff</a> : flow_action

    val <a href="#val-tc.ion">ion</a> : flow_action

    eqtype <a href="#type-tc.queue_sel">queue_sel</a>

    val <a href="#val-tc.iflush">iflush</a> : queue_sel

    val <a href="#val-tc.oflush">oflush</a> : queue_sel

    val <a href="#val-tc.ioflush">ioflush</a> : queue_sel

    val <a href="#val-tc.getattr">getattr</a> : file_desc -&gt; termios

    val <a href="#val-tc.setattr">setattr</a> : file_desc * set_action * termios -&gt; unit

    val <a href="#val-tc.sendbreak">sendbreak</a> : file_desc * int -&gt; unit

    val <a href="#val-tc.drain">drain</a> : file_desc -&gt; unit

    val <a href="#val-tc.flush">flush</a> : file_desc * queue_sel -&gt; unit

    val <a href="#val-tc.flow">flow</a> : file_desc * flow_action -&gt; unit

    val <a href="#val-tc.getpgrp">getpgrp</a> : file_desc -&gt; pid

    val <a href="#val-tc.setpgrp">setpgrp</a> : file_desc * pid -&gt; unit
  end
end
</pre>

### <a name="type-pid"></a>`pid`

```sml
eqtype pid
```

The type of the number that names a process, the one of [`Posix.Process`](../sig/POSIX.md#str-process).

### <a name="type-file_desc"></a>`file_desc`

```sml
eqtype file_desc
```

The type of an open file descriptor.

### <a name="str-v"></a>`V`

The positions in the array of control characters, and the array itself.

#### <a name="val-v.eof"></a>`eof`

```sml
val eof : int
```

Where the end-of-file character stands.

> **Reading** `Posix.TTY.V/distinct-within-a-set`. POSIX lets [`min`](#val-v.min) share
> its position with [`eof`](#val-v.eof), and [`time`](#val-v.time) with [`eol`](#val-v.eol), because a terminal is
> either in canonical mode or not; so the positions are distinct within
> each of the two sets and not across them.

<details><summary>Tests (2)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index` &middot; `distinct`

</details>

#### <a name="val-v.eol"></a>`eol`

```sml
val eol : int
```

Where the end-of-line character stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index`

</details>

#### <a name="val-v.erase"></a>`erase`

```sml
val erase : int
```

Where the character that erases one character stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index`

</details>

#### <a name="val-v.intr"></a>`intr`

```sml
val intr : int
```

Where the character that sends the interrupt signal stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index`

</details>

#### <a name="val-v.kill"></a>`kill`

```sml
val kill : int
```

Where the character that erases the whole line stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index`

</details>

#### <a name="val-v.min"></a>`min`

```sml
val min : int
```

Where the smallest number of characters a raw read waits for stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index`

</details>

#### <a name="val-v.quit"></a>`quit`

```sml
val quit : int
```

Where the character that sends the quit signal stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index`

</details>

#### <a name="val-v.susp"></a>`susp`

```sml
val susp : int
```

Where the character that suspends the program stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index`

</details>

#### <a name="val-v.time"></a>`time`

```sml
val time : int
```

Where the time a raw read waits, in tenths of a second, stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index`

</details>

#### <a name="val-v.start"></a>`start`

```sml
val start : int
```

Where the character that resumes output stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index`

</details>

#### <a name="val-v.stop"></a>`stop`

```sml
val stop : int
```

Where the character that holds output back stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `index`

</details>

#### <a name="val-v.nccs"></a>`nccs`

```sml
val nccs : int
```

How many positions the array has.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `positive`

</details>

#### <a name="type-v.cc"></a>`cc`

```sml
type cc
```

The type of the array of control characters.

<details><summary>Tests (4)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `given` &middot; `unspecified-nul` &middot; `empty` &middot; `several`

</details>

#### <a name="val-v.cc"></a>`cc`

```sml
val cc : (int * char) list -> cc
```

`cc l` is the array in which each position of `l` holds its character, and every other position `#"\000"`.

<details><summary>Tests (4)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `given` &middot; `unspecified-nul` &middot; `empty` &middot; `several`

</details>

#### <a name="val-v.update"></a>`update`

```sml
val update : cc * (int * char) list -> cc
```

`update (c, l)` is a copy of `c` in which each position of `l` holds its character.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if a position is outside `[0, nccs)`.

<details><summary>Tests (2)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `overwrites` &middot; `empty-list`

</details>

#### <a name="val-v.sub"></a>`sub`

```sml
val sub : cc * int -> char
```

`sub (c, i)` is the character at position `i`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` is outside `[0, nccs)`.

<details><summary>Tests (3)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `last` &middot; `negative` (raises Subscript) &middot; `nccs` (raises Subscript)

</details>

### <a name="str-i"></a>`I`

What the terminal does with what is typed at it.

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype | The type of a set of flags. |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val | `toWord fl` is the word whose bits are the flags of `fl`. |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val | `fromWord w` is the set of the flags that the bits of `w` name. |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val | Every flag the system uses here. |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val | `flags l` is the union of the sets of `l`: a flag is in it when it is in one of them. |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val | `intersect l` is the intersection of the sets of `l`: a flag is in it when it is in all of them. |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val | `clear (fl, gl)` is `gl` without the flags of `fl`. |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val | `allSet (fl, gl)` is `true` when every flag of `fl` is in `gl`. |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val | `anySet (fl, gl)` is `true` when some flag of `fl` is in `gl`. |

#### <a name="val-i.brkint"></a>`brkint`

```sml
val brkint : flags
```

A break sends the interrupt signal.

> **Reading** `Posix.TTY.I/bits-are-posix's`. The page says nothing about
> what bits these flags have; the suite follows POSIX and asks that
> every named flag of [`I`](#str-i) and [`L`](#str-l) have non-zero bits of its own inside
> [`all`](../sig/BIT_FLAGS.md#val-all), comparing through `SysWord` rather than through [`allSet`](../sig/BIT_FLAGS.md#val-allset).

<details><summary>Tests (2)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit` &middot; `disjoint`

</details>

#### <a name="val-i.icrnl"></a>`icrnl`

```sml
val icrnl : flags
```

A carriage return arrives as a newline.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-i.ignbrk"></a>`ignbrk`

```sml
val ignbrk : flags
```

A break is ignored.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-i.igncr"></a>`igncr`

```sml
val igncr : flags
```

A carriage return is dropped.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-i.ignpar"></a>`ignpar`

```sml
val ignpar : flags
```

A character with a parity error is dropped.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-i.inlcr"></a>`inlcr`

```sml
val inlcr : flags
```

A newline arrives as a carriage return.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-i.inpck"></a>`inpck`

```sml
val inpck : flags
```

Check the parity of what arrives.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-i.istrip"></a>`istrip`

```sml
val istrip : flags
```

Drop the eighth bit of every character.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-i.ixoff"></a>`ixoff`

```sml
val ixoff : flags
```

Send the stop character when the input buffer fills.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-i.ixon"></a>`ixon`

```sml
val ixon : flags
```

Let the terminal hold output back with the stop character.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-i.parmrk"></a>`parmrk`

```sml
val parmrk : flags
```

Mark a character with a parity error rather than dropping it.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

### <a name="str-o"></a>`O`

What the terminal does with what is written to it.

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype | The type of a set of flags. |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val | `toWord fl` is the word whose bits are the flags of `fl`. |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val | `fromWord w` is the set of the flags that the bits of `w` name. |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val | Every flag the system uses here. |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val | `flags l` is the union of the sets of `l`: a flag is in it when it is in one of them. |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val | `intersect l` is the intersection of the sets of `l`: a flag is in it when it is in all of them. |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val | `clear (fl, gl)` is `gl` without the flags of `fl`. |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val | `allSet (fl, gl)` is `true` when every flag of `fl` is in `gl`. |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val | `anySet (fl, gl)` is `true` when some flag of `fl` is in `gl`. |

#### <a name="val-o.opost"></a>`opost`

```sml
val opost : flags
```

Process output at all; without it, output goes out as it stands.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

### <a name="str-c"></a>`C`

The line itself: how wide a character is, how it is checked, how fast it goes.

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype | The type of a set of flags. |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val | `toWord fl` is the word whose bits are the flags of `fl`. |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val | `fromWord w` is the set of the flags that the bits of `w` name. |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val | Every flag the system uses here. |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val | `flags l` is the union of the sets of `l`: a flag is in it when it is in one of them. |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val | `intersect l` is the intersection of the sets of `l`: a flag is in it when it is in all of them. |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val | `clear (fl, gl)` is `gl` without the flags of `fl`. |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val | `allSet (fl, gl)` is `true` when every flag of `fl` is in `gl`. |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val | `anySet (fl, gl)` is `true` when some flag of `fl` is in `gl`. |

#### <a name="val-c.clocal"></a>`clocal`

```sml
val clocal : flags
```

Ignore the modem lines: the line is local.

<details><summary>Tests (2)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit` &middot; `disjoint`

</details>

#### <a name="val-c.cread"></a>`cread`

```sml
val cread : flags
```

Let the terminal be read at all.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-c.cs5"></a>`cs5`

```sml
val cs5 : flags
```

Characters of five bits.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `in-csize`

</details>

#### <a name="val-c.cs6"></a>`cs6`

```sml
val cs6 : flags
```

Characters of six bits.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `in-csize`

</details>

#### <a name="val-c.cs7"></a>`cs7`

```sml
val cs7 : flags
```

Characters of seven bits.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `in-csize`

</details>

#### <a name="val-c.cs8"></a>`cs8`

```sml
val cs8 : flags
```

Characters of eight bits.

<details><summary>Tests (2)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `in-csize` &middot; `distinct-sizes`

</details>

#### <a name="val-c.csize"></a>`csize`

```sml
val csize : flags
```

The bits that hold the character width: [`cs5`](#val-c.cs5) to [`cs8`](#val-c.cs8) lie inside it.

<details><summary>Tests (2)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit` &middot; `union-of-sizes`

</details>

#### <a name="val-c.cstopb"></a>`cstopb`

```sml
val cstopb : flags
```

Send two stop bits rather than one.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-c.hupcl"></a>`hupcl`

```sml
val hupcl : flags
```

Hang up the line when the last process closes it.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-c.parenb"></a>`parenb`

```sml
val parenb : flags
```

Generate and check a parity bit.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-c.parodd"></a>`parodd`

```sml
val parodd : flags
```

Make that parity odd rather than even.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

### <a name="str-l"></a>`L`

How the terminal treats the program: echoing, lines, signals.

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype | The type of a set of flags. |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val | `toWord fl` is the word whose bits are the flags of `fl`. |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val | `fromWord w` is the set of the flags that the bits of `w` name. |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val | Every flag the system uses here. |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val | `flags l` is the union of the sets of `l`: a flag is in it when it is in one of them. |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val | `intersect l` is the intersection of the sets of `l`: a flag is in it when it is in all of them. |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val | `clear (fl, gl)` is `gl` without the flags of `fl`. |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val | `allSet (fl, gl)` is `true` when every flag of `fl` is in `gl`. |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val | `anySet (fl, gl)` is `true` when some flag of `fl` is in `gl`. |

#### <a name="val-l.echo"></a>`echo`

```sml
val echo : flags
```

Echo what is typed.

<details><summary>Tests (2)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit` &middot; `disjoint`

</details>

#### <a name="val-l.echoe"></a>`echoe`

```sml
val echoe : flags
```

Echo the erase character as erasing.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-l.echok"></a>`echok`

```sml
val echok : flags
```

Echo the kill character as killing the line.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-l.echonl"></a>`echonl`

```sml
val echonl : flags
```

Echo a newline even when [`echo`](#val-l.echo) is off.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-l.icanon"></a>`icanon`

```sml
val icanon : flags
```

Wait for a whole line, and let it be edited; without it, keys arrive as they are typed.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-l.iexten"></a>`iexten`

```sml
val iexten : flags
```

Allow the system's own extensions to line editing.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-l.isig"></a>`isig`

```sml
val isig : flags
```

Let the interrupt, quit and suspend characters send their signals.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-l.noflsh"></a>`noflsh`

```sml
val noflsh : flags
```

Do not flush the buffers when one of those signals is sent.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

#### <a name="val-l.tostop"></a>`tostop`

```sml
val tostop : flags
```

Stop a background process that writes to the terminal.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `own-bit`

</details>

### <a name="type-speed"></a>`speed`

```sml
eqtype speed
```

The type of a line speed.

> **Implementation** `Posix.TTY.speed/is-speed_t`. It is the system's
> `speed_t`, and the named speeds are ordered by their baud rate.

### <a name="val-comparespeed"></a>`compareSpeed`

```sml
val compareSpeed : speed * speed -> order
```

`compareSpeed (s, t)` orders two speeds, the slower first.

<details><summary>Tests (2)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `basic` &middot; `antisymmetric`

</details>

### <a name="val-speedtoword"></a>`speedToWord`

```sml
val speedToWord : speed -> SysWord.word
```

`speedToWord s` is the `speed_t` value of `s`.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `distinct`

</details>

### <a name="val-wordtospeed"></a>`wordToSpeed`

```sml
val wordToSpeed : SysWord.word -> speed
```

`wordToSpeed w` is the speed whose `speed_t` value is `w`.

<details><summary>Tests (2)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `of-speedToWord` &middot; `no-check`

</details>

### <a name="val-b0"></a>`b0`

```sml
val b0 : speed
```

Hang up: zero baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `slowest`

</details>

### <a name="val-b50"></a>`b50`

```sml
val b50 : speed
```

50 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b75"></a>`b75`

```sml
val b75 : speed
```

75 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b110"></a>`b110`

```sml
val b110 : speed
```

110 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b134"></a>`b134`

```sml
val b134 : speed
```

134\.5 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b150"></a>`b150`

```sml
val b150 : speed
```

150 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b200"></a>`b200`

```sml
val b200 : speed
```

200 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b300"></a>`b300`

```sml
val b300 : speed
```

300 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b600"></a>`b600`

```sml
val b600 : speed
```

600 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b1200"></a>`b1200`

```sml
val b1200 : speed
```

1200 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b1800"></a>`b1800`

```sml
val b1800 : speed
```

1800 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b2400"></a>`b2400`

```sml
val b2400 : speed
```

2400 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b4800"></a>`b4800`

```sml
val b4800 : speed
```

4800 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b9600"></a>`b9600`

```sml
val b9600 : speed
```

9600 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b19200"></a>`b19200`

```sml
val b19200 : speed
```

19200 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `rank`

</details>

### <a name="val-b38400"></a>`b38400`

```sml
val b38400 : speed
```

38400 baud.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `fastest`

</details>

### <a name="type-termios"></a>`termios`

```sml
type termios
```

The whole of a terminal's settings.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `fieldsOf`

</details>

### <a name="val-termios"></a>`termios`

```sml
val termios : {iflag : I.flags,
               oflag : O.flags,
               cflag : C.flags,
               lflag : L.flags,
               cc : V.cc,
               ispeed : speed,
               ospeed : speed}
              -> termios
```

`termios {iflag, oflag, cflag, lflag, cc, ispeed, ospeed}` is the settings those fields make.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-termios.iflag"></a>`iflag` | `I.flags` |  |
| <a name="fld-termios.oflag"></a>`oflag` | `O.flags` |  |
| <a name="fld-termios.cflag"></a>`cflag` | `C.flags` |  |
| <a name="fld-termios.lflag"></a>`lflag` | `L.flags` |  |
| <a name="fld-termios.cc"></a>`cc` | `V.cc` |  |
| <a name="fld-termios.ispeed"></a>`ispeed` | `speed` |  |
| <a name="fld-termios.ospeed"></a>`ospeed` | `speed` |  |

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `fieldsOf`

</details>

### <a name="val-fieldsof"></a>`fieldsOf`

```sml
val fieldsOf : termios
               -> {iflag : I.flags,
                   oflag : O.flags,
                   cflag : C.flags,
                   lflag : L.flags,
                   cc : V.cc,
                   ispeed : speed,
                   ospeed : speed}
```

`fieldsOf t` is the fields of `t`, the record that [`termios`](#val-termios) takes.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-fieldsof.iflag"></a>`iflag` | `I.flags` |  |
| <a name="fld-fieldsof.oflag"></a>`oflag` | `O.flags` |  |
| <a name="fld-fieldsof.cflag"></a>`cflag` | `C.flags` |  |
| <a name="fld-fieldsof.lflag"></a>`lflag` | `L.flags` |  |
| <a name="fld-fieldsof.cc"></a>`cc` | `V.cc` |  |
| <a name="fld-fieldsof.ispeed"></a>`ispeed` | `speed` |  |
| <a name="fld-fieldsof.ospeed"></a>`ospeed` | `speed` |  |

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `termios`

</details>

### <a name="val-getiflag"></a>`getiflag`

```sml
val getiflag : termios -> I.flags
```

`getiflag t` is the input flags of `t`.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `sample`

</details>

### <a name="val-getoflag"></a>`getoflag`

```sml
val getoflag : termios -> O.flags
```

`getoflag t` is the output flags of `t`.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `sample`

</details>

### <a name="val-getcflag"></a>`getcflag`

```sml
val getcflag : termios -> C.flags
```

`getcflag t` is the line flags of `t`.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `sample`

</details>

### <a name="val-getlflag"></a>`getlflag`

```sml
val getlflag : termios -> L.flags
```

`getlflag t` is the local flags of `t`.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `sample`

</details>

### <a name="val-getcc"></a>`getcc`

```sml
val getcc : termios -> V.cc
```

`getcc t` is the array of control characters of `t`.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `sample`

</details>

### <a name="str-cf"></a>`CF`

The speeds of a settings record, read and set.

#### <a name="val-cf.getospeed"></a>`getospeed`

```sml
val getospeed : termios -> speed
```

`getospeed t` is the speed at which `t` sends.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `sample`

</details>

#### <a name="val-cf.getispeed"></a>`getispeed`

```sml
val getispeed : termios -> speed
```

`getispeed t` is the speed at which `t` receives.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `sample`

</details>

#### <a name="val-cf.setospeed"></a>`setospeed`

```sml
val setospeed : termios * speed -> termios
```

`setospeed (t, s)` is `t` with `s` as the speed it sends at.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `copy`

</details>

#### <a name="val-cf.setispeed"></a>`setispeed`

```sml
val setispeed : termios * speed -> termios
```

`setispeed (t, s)` is `t` with `s` as the speed it receives at.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `copy`

</details>

### <a name="str-tc"></a>`TC`

The operations on a terminal itself: reading and writing its settings, and controlling its queues.

> **Reading** `Posix.TTY.TC/not-a-terminal-raises`. The page does not say
> what happens on a descriptor that is not a terminal; POSIX reports
> `notty`, so every operation here raises [`OS.SysErr`](../sig/OS.md#exn-syserr) for one.

#### <a name="type-tc.set_action"></a>`set_action`

```sml
eqtype set_action
```

When [`setattr`](#val-tc.setattr) is to take effect.

#### <a name="val-tc.sanow"></a>`sanow`

```sml
val sanow : set_action
```

At once.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `distinct`

</details>

#### <a name="val-tc.sadrain"></a>`sadrain`

```sml
val sadrain : set_action
```

Once what has been written has gone out.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-sanow`

</details>

#### <a name="val-tc.saflush"></a>`saflush`

```sml
val saflush : set_action
```

Once what has been written has gone out, discarding what has come in.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-sadrain`

</details>

#### <a name="type-tc.flow_action"></a>`flow_action`

```sml
eqtype flow_action
```

What [`flow`](#val-tc.flow) is to do.

#### <a name="val-tc.ooff"></a>`ooff`

```sml
val ooff : flow_action
```

Hold output back.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `distinct`

</details>

#### <a name="val-tc.oon"></a>`oon`

```sml
val oon : flow_action
```

Let output go on.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-ooff`

</details>

#### <a name="val-tc.ioff"></a>`ioff`

```sml
val ioff : flow_action
```

Send the stop character, asking the terminal to hold back.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-ion`

</details>

#### <a name="val-tc.ion"></a>`ion`

```sml
val ion : flow_action
```

Send the start character, asking the terminal to go on.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-oon`

</details>

#### <a name="type-tc.queue_sel"></a>`queue_sel`

```sml
eqtype queue_sel
```

Which queue [`flush`](#val-tc.flush) is to empty.

#### <a name="val-tc.iflush"></a>`iflush`

```sml
val iflush : queue_sel
```

What has come in and not been read.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `distinct`

</details>

#### <a name="val-tc.oflush"></a>`oflush`

```sml
val oflush : queue_sel
```

What has been written and not gone out.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-iflush`

</details>

#### <a name="val-tc.ioflush"></a>`ioflush`

```sml
val ioflush : queue_sel
```

Both.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-oflush`

</details>

#### <a name="val-tc.getattr"></a>`getattr`

```sml
val getattr : file_desc -> termios
```

`getattr fd` is the settings of the terminal `fd` is open on.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not a terminal.

<details><summary>Tests (2)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-a-terminal` (raises) &middot; `bad-descriptor` (raises)

</details>

#### <a name="val-tc.setattr"></a>`setattr`

```sml
val setattr : file_desc * set_action * termios -> unit
```

`setattr (fd, when, t)` gives the terminal the settings `t`, at the moment `when` names.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not a terminal, or the settings are
refused.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-a-terminal` (raises)

</details>

#### <a name="val-tc.sendbreak"></a>`sendbreak`

```sml
val sendbreak : file_desc * int -> unit
```

`sendbreak (fd, n)` sends a break of `n` units, or of the usual length when `n` is 0.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not a terminal.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-a-terminal` (raises)

</details>

#### <a name="val-tc.drain"></a>`drain`

```sml
val drain : file_desc -> unit
```

`drain fd` waits until what was written to the terminal has gone out.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not a terminal.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-a-terminal` (raises)

</details>

#### <a name="val-tc.flush"></a>`flush`

```sml
val flush : file_desc * queue_sel -> unit
```

`flush (fd, which)` throws away what is in the queue that `which` names.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not a terminal.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-a-terminal` (raises)

</details>

#### <a name="val-tc.flow"></a>`flow`

```sml
val flow : file_desc * flow_action -> unit
```

`flow (fd, what)` holds the flow back or lets it go on, as `what` says.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not a terminal.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-a-terminal` (raises)

</details>

#### <a name="val-tc.getpgrp"></a>`getpgrp`

```sml
val getpgrp : file_desc -> pid
```

`getpgrp fd` is the process group that the terminal sends its signals to.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not a terminal.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-a-terminal` (raises)

</details>

#### <a name="val-tc.setpgrp"></a>`setpgrp`

```sml
val setpgrp : file_desc * pid -> unit
```

`setpgrp (fd, pgid)` makes `pgid` the process group in the foreground of the terminal.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not a terminal, or the change is
refused.

<details><summary>Tests (1)</summary>

For `Posix.TTY`, in [tests/basis/posix\_tty.sml](../../../../tests/basis/posix_tty.sml): `not-a-terminal` (raises)

</details>

## See also

[`POSIX_IO`](../sig/POSIX_IO.md), [`POSIX_PROC_ENV`](../sig/POSIX_PROC_ENV.md), [`POSIX`](../sig/POSIX.md), [`BIT_FLAGS`](../sig/BIT_FLAGS.md)

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_tty.sml; do not edit.</sub>
