# signature POSIX_TTY

[The Standard ML Basis Library](../README.md) &rsaquo; **POSIX_TTY**

|  |  |
| --- | --- |
| Status | required |
| Documentation | 0 of 110 entries documented |
| Source | [lib/basis/sig\_posix\_tty.sml](../../../../lib/basis/sig_posix_tty.sml) |

## Synopsis

```sml
signature POSIX_TTY
```

signature POSIX\_TTY, transcribed from
<https://smlfamily.github.io/Basis/posix-tty.html>

Uses BIT\_FLAGS (spec-sigs/BIT\_FLAGS.sml), which has to be loaded
first: the substructures I, O, C and L `include BIT_FLAGS`. The types pid
and file\_desc are left flexible, as on the page; POSIX fixes them
(spec-sigs/POSIX.sml).

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

### <a name="type-file_desc"></a>`file_desc`

```sml
eqtype file_desc
```

### <a name="str-v"></a>`V`

#### <a name="val-v.eof"></a>`eof`

```sml
val eof : int
```

#### <a name="val-v.eol"></a>`eol`

```sml
val eol : int
```

#### <a name="val-v.erase"></a>`erase`

```sml
val erase : int
```

#### <a name="val-v.intr"></a>`intr`

```sml
val intr : int
```

#### <a name="val-v.kill"></a>`kill`

```sml
val kill : int
```

#### <a name="val-v.min"></a>`min`

```sml
val min : int
```

#### <a name="val-v.quit"></a>`quit`

```sml
val quit : int
```

#### <a name="val-v.susp"></a>`susp`

```sml
val susp : int
```

#### <a name="val-v.time"></a>`time`

```sml
val time : int
```

#### <a name="val-v.start"></a>`start`

```sml
val start : int
```

#### <a name="val-v.stop"></a>`stop`

```sml
val stop : int
```

#### <a name="val-v.nccs"></a>`nccs`

```sml
val nccs : int
```

#### <a name="type-v.cc"></a>`cc`

```sml
type cc
```

#### <a name="val-v.cc"></a>`cc`

```sml
val cc : (int * char) list -> cc
```

#### <a name="val-v.update"></a>`update`

```sml
val update : cc * (int * char) list -> cc
```

#### <a name="val-v.sub"></a>`sub`

```sml
val sub : cc * int -> char
```

### <a name="str-i"></a>`I`

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

#### <a name="val-i.brkint"></a>`brkint`

```sml
val brkint : flags
```

#### <a name="val-i.icrnl"></a>`icrnl`

```sml
val icrnl : flags
```

#### <a name="val-i.ignbrk"></a>`ignbrk`

```sml
val ignbrk : flags
```

#### <a name="val-i.igncr"></a>`igncr`

```sml
val igncr : flags
```

#### <a name="val-i.ignpar"></a>`ignpar`

```sml
val ignpar : flags
```

#### <a name="val-i.inlcr"></a>`inlcr`

```sml
val inlcr : flags
```

#### <a name="val-i.inpck"></a>`inpck`

```sml
val inpck : flags
```

#### <a name="val-i.istrip"></a>`istrip`

```sml
val istrip : flags
```

#### <a name="val-i.ixoff"></a>`ixoff`

```sml
val ixoff : flags
```

#### <a name="val-i.ixon"></a>`ixon`

```sml
val ixon : flags
```

#### <a name="val-i.parmrk"></a>`parmrk`

```sml
val parmrk : flags
```

### <a name="str-o"></a>`O`

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

#### <a name="val-o.opost"></a>`opost`

```sml
val opost : flags
```

### <a name="str-c"></a>`C`

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

#### <a name="val-c.clocal"></a>`clocal`

```sml
val clocal : flags
```

#### <a name="val-c.cread"></a>`cread`

```sml
val cread : flags
```

#### <a name="val-c.cs5"></a>`cs5`

```sml
val cs5 : flags
```

#### <a name="val-c.cs6"></a>`cs6`

```sml
val cs6 : flags
```

#### <a name="val-c.cs7"></a>`cs7`

```sml
val cs7 : flags
```

#### <a name="val-c.cs8"></a>`cs8`

```sml
val cs8 : flags
```

#### <a name="val-c.csize"></a>`csize`

```sml
val csize : flags
```

#### <a name="val-c.cstopb"></a>`cstopb`

```sml
val cstopb : flags
```

#### <a name="val-c.hupcl"></a>`hupcl`

```sml
val hupcl : flags
```

#### <a name="val-c.parenb"></a>`parenb`

```sml
val parenb : flags
```

#### <a name="val-c.parodd"></a>`parodd`

```sml
val parodd : flags
```

### <a name="str-l"></a>`L`

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

#### <a name="val-l.echo"></a>`echo`

```sml
val echo : flags
```

#### <a name="val-l.echoe"></a>`echoe`

```sml
val echoe : flags
```

#### <a name="val-l.echok"></a>`echok`

```sml
val echok : flags
```

#### <a name="val-l.echonl"></a>`echonl`

```sml
val echonl : flags
```

#### <a name="val-l.icanon"></a>`icanon`

```sml
val icanon : flags
```

#### <a name="val-l.iexten"></a>`iexten`

```sml
val iexten : flags
```

#### <a name="val-l.isig"></a>`isig`

```sml
val isig : flags
```

#### <a name="val-l.noflsh"></a>`noflsh`

```sml
val noflsh : flags
```

#### <a name="val-l.tostop"></a>`tostop`

```sml
val tostop : flags
```

### <a name="type-speed"></a>`speed`

```sml
eqtype speed
```

### <a name="val-comparespeed"></a>`compareSpeed`

```sml
val compareSpeed : speed * speed -> order
```

### <a name="val-speedtoword"></a>`speedToWord`

```sml
val speedToWord : speed -> SysWord.word
```

### <a name="val-wordtospeed"></a>`wordToSpeed`

```sml
val wordToSpeed : SysWord.word -> speed
```

### <a name="val-b0"></a>`b0`

```sml
val b0 : speed
```

### <a name="val-b50"></a>`b50`

```sml
val b50 : speed
```

### <a name="val-b75"></a>`b75`

```sml
val b75 : speed
```

### <a name="val-b110"></a>`b110`

```sml
val b110 : speed
```

### <a name="val-b134"></a>`b134`

```sml
val b134 : speed
```

### <a name="val-b150"></a>`b150`

```sml
val b150 : speed
```

### <a name="val-b200"></a>`b200`

```sml
val b200 : speed
```

### <a name="val-b300"></a>`b300`

```sml
val b300 : speed
```

### <a name="val-b600"></a>`b600`

```sml
val b600 : speed
```

### <a name="val-b1200"></a>`b1200`

```sml
val b1200 : speed
```

### <a name="val-b1800"></a>`b1800`

```sml
val b1800 : speed
```

### <a name="val-b2400"></a>`b2400`

```sml
val b2400 : speed
```

### <a name="val-b4800"></a>`b4800`

```sml
val b4800 : speed
```

### <a name="val-b9600"></a>`b9600`

```sml
val b9600 : speed
```

### <a name="val-b19200"></a>`b19200`

```sml
val b19200 : speed
```

### <a name="val-b38400"></a>`b38400`

```sml
val b38400 : speed
```

### <a name="type-termios"></a>`termios`

```sml
type termios
```

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

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-termios.iflag"></a>`iflag` | `I.flags` |  |
| <a name="fld-termios.oflag"></a>`oflag` | `O.flags` |  |
| <a name="fld-termios.cflag"></a>`cflag` | `C.flags` |  |
| <a name="fld-termios.lflag"></a>`lflag` | `L.flags` |  |
| <a name="fld-termios.cc"></a>`cc` | `V.cc` |  |
| <a name="fld-termios.ispeed"></a>`ispeed` | `speed` |  |
| <a name="fld-termios.ospeed"></a>`ospeed` | `speed` |  |

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

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-fieldsof.iflag"></a>`iflag` | `I.flags` |  |
| <a name="fld-fieldsof.oflag"></a>`oflag` | `O.flags` |  |
| <a name="fld-fieldsof.cflag"></a>`cflag` | `C.flags` |  |
| <a name="fld-fieldsof.lflag"></a>`lflag` | `L.flags` |  |
| <a name="fld-fieldsof.cc"></a>`cc` | `V.cc` |  |
| <a name="fld-fieldsof.ispeed"></a>`ispeed` | `speed` |  |
| <a name="fld-fieldsof.ospeed"></a>`ospeed` | `speed` |  |

### <a name="val-getiflag"></a>`getiflag`

```sml
val getiflag : termios -> I.flags
```

### <a name="val-getoflag"></a>`getoflag`

```sml
val getoflag : termios -> O.flags
```

### <a name="val-getcflag"></a>`getcflag`

```sml
val getcflag : termios -> C.flags
```

### <a name="val-getlflag"></a>`getlflag`

```sml
val getlflag : termios -> L.flags
```

### <a name="val-getcc"></a>`getcc`

```sml
val getcc : termios -> V.cc
```

### <a name="str-cf"></a>`CF`

#### <a name="val-cf.getospeed"></a>`getospeed`

```sml
val getospeed : termios -> speed
```

#### <a name="val-cf.getispeed"></a>`getispeed`

```sml
val getispeed : termios -> speed
```

#### <a name="val-cf.setospeed"></a>`setospeed`

```sml
val setospeed : termios * speed -> termios
```

#### <a name="val-cf.setispeed"></a>`setispeed`

```sml
val setispeed : termios * speed -> termios
```

### <a name="str-tc"></a>`TC`

#### <a name="type-tc.set_action"></a>`set_action`

```sml
eqtype set_action
```

#### <a name="val-tc.sanow"></a>`sanow`

```sml
val sanow : set_action
```

#### <a name="val-tc.sadrain"></a>`sadrain`

```sml
val sadrain : set_action
```

#### <a name="val-tc.saflush"></a>`saflush`

```sml
val saflush : set_action
```

#### <a name="type-tc.flow_action"></a>`flow_action`

```sml
eqtype flow_action
```

#### <a name="val-tc.ooff"></a>`ooff`

```sml
val ooff : flow_action
```

#### <a name="val-tc.oon"></a>`oon`

```sml
val oon : flow_action
```

#### <a name="val-tc.ioff"></a>`ioff`

```sml
val ioff : flow_action
```

#### <a name="val-tc.ion"></a>`ion`

```sml
val ion : flow_action
```

#### <a name="type-tc.queue_sel"></a>`queue_sel`

```sml
eqtype queue_sel
```

#### <a name="val-tc.iflush"></a>`iflush`

```sml
val iflush : queue_sel
```

#### <a name="val-tc.oflush"></a>`oflush`

```sml
val oflush : queue_sel
```

#### <a name="val-tc.ioflush"></a>`ioflush`

```sml
val ioflush : queue_sel
```

#### <a name="val-tc.getattr"></a>`getattr`

```sml
val getattr : file_desc -> termios
```

#### <a name="val-tc.setattr"></a>`setattr`

```sml
val setattr : file_desc * set_action * termios -> unit
```

#### <a name="val-tc.sendbreak"></a>`sendbreak`

```sml
val sendbreak : file_desc * int -> unit
```

#### <a name="val-tc.drain"></a>`drain`

```sml
val drain : file_desc -> unit
```

#### <a name="val-tc.flush"></a>`flush`

```sml
val flush : file_desc * queue_sel -> unit
```

#### <a name="val-tc.flow"></a>`flow`

```sml
val flow : file_desc * flow_action -> unit
```

#### <a name="val-tc.getpgrp"></a>`getpgrp`

```sml
val getpgrp : file_desc -> pid
```

#### <a name="val-tc.setpgrp"></a>`setpgrp`

```sml
val setpgrp : file_desc * pid -> unit
```

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_tty.sml; do not edit.</sub>
