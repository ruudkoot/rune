# signature SYSTEM_ARB

[Property testing](../README.md) &rsaquo; Property testing &rsaquo; **SYSTEM_ARB**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 23 of 23 entries documented |
| Tests | not listed |
| Source | [lib/test/property/system\_sig.sml](../../../../../lib/test/property/system_sig.sml) |

## Synopsis

```sml
signature SYSTEM_ARB
structure SystemArb :> SYSTEM_ARB
```

| Implementation |  | Source |
| --- | --- | --- |
| [`SystemArb`](../str/SystemArb.md) |  | [lib/test/property/system.sml](../../../../../lib/test/property/system.sml) |

The arbitraries of the values of the operating system that the Basis
Library's laws are written over (docs/plans/quickcheck.md, M6).

These are made, not drawn: a stream over drawn bytes or a file in a
scratch directory, a pipe, a socket, the process's own ids. What a case
makes is undone when the case is over ([`Gen.resource`](../sig/GEN.md#val-resource)). A value with no
Standard ML that makes it again is shown as a comment that says what it
is.

## Interface

<pre>
signature SYSTEM_ARB =
sig
  val <a href="#val-bininstream">binInstream</a> : BinIO.instream Arb.arb
  val <a href="#val-binstreaminstream">binStreamInstream</a> : BinIO.StreamIO.instream Arb.arb
  val <a href="#val-binwriter">binWriter</a> : BinIO.StreamIO.writer Arb.arb
  val <a href="#val-binoutstream">binOutstream</a> : BinIO.StreamIO.outstream Arb.arb
  val <a href="#val-iodesc">iodesc</a> : OS.IO.iodesc Arb.arb
  val <a href="#val-polldesc">pollDesc</a> : OS.IO.poll_desc Arb.arb
  val <a href="#val-fileid">fileId</a> : OS.FileSys.file_id Arb.arb
  val <a href="#val-syserror">syserror</a> : OS.syserror Arb.arb
  val <a href="#val-filedesc">fileDesc</a> : Posix.FileSys.file_desc Arb.arb
  val <a href="#val-pid">pid</a> : Posix.Process.pid Arb.arb
  val <a href="#val-signal">signal</a> : Posix.Signal.signal Arb.arb
  val <a href="#val-uid">uid</a> : Posix.ProcEnv.uid Arb.arb
  val <a href="#val-gid">gid</a> : Posix.ProcEnv.gid Arb.arb
  val <a href="#val-speed">speed</a> : Posix.TTY.speed Arb.arb
  val <a href="#val-termios">termios</a> : Posix.TTY.termios Arb.arb
  val <a href="#val-termiosfields">termiosFields</a> : {<a href="#fld-termiosfields.iflag">iflag</a> : Posix.TTY.I.flags, <a href="#fld-termiosfields.oflag">oflag</a> : Posix.TTY.O.flags, <a href="#fld-termiosfields.cflag">cflag</a> : Posix.TTY.C.flags,
                       <a href="#fld-termiosfields.lflag">lflag</a> : Posix.TTY.L.flags, <a href="#fld-termiosfields.cc">cc</a> : Posix.TTY.V.cc, <a href="#fld-termiosfields.ispeed">ispeed</a> : Posix.TTY.speed,
                       <a href="#fld-termiosfields.ospeed">ospeed</a> : Posix.TTY.speed} Arb.arb
  val <a href="#val-whence">whence</a> : Posix.IO.whence Arb.arb
  val <a href="#val-locktype">lockType</a> : Posix.IO.lock_type Arb.arb
  val <a href="#val-addrfamily">addrFamily</a> : Socket.AF.addr_family Arb.arb
  val <a href="#val-socktype">sockType</a> : Socket.SOCK.sock_type Arb.arb
  val <a href="#val-inetstreamsock">inetStreamSock</a> : unit -&gt; 'mode INetSock.stream_sock Arb.arb
  val <a href="#val-inaddr">inAddr</a> : NetHostDB.in_addr Arb.arb
  val <a href="#val-hostentry">hostEntry</a> : NetHostDB.entry Arb.arb
end
</pre>

### <a name="val-bininstream"></a>`binInstream`

```sml
val binInstream : BinIO.instream Arb.arb
```

The arbitrary of binary input streams over drawn bytes, shown as the
bytes they have left.

### <a name="val-binstreaminstream"></a>`binStreamInstream`

```sml
val binStreamInstream : BinIO.StreamIO.instream Arb.arb
```

The arbitrary of functional binary input streams over drawn bytes.

### <a name="val-binwriter"></a>`binWriter`

```sml
val binWriter : BinIO.StreamIO.writer Arb.arb
```

The arbitrary of binary writers that keep what they are given and
accept every write.

### <a name="val-binoutstream"></a>`binOutstream`

```sml
val binOutstream : BinIO.StreamIO.outstream Arb.arb
```

The arbitrary of functional binary output streams over a writer of
[`binWriter`](#val-binwriter), with any buffer mode.

### <a name="val-iodesc"></a>`iodesc`

```sml
val iodesc : OS.IO.iodesc Arb.arb
```

The arbitrary of I/O descriptors: the read end of a pipe, closed when
the case is over.

### <a name="val-polldesc"></a>`pollDesc`

```sml
val pollDesc : OS.IO.poll_desc Arb.arb
```

The arbitrary of poll descriptors of [`iodesc`](#val-iodesc)'s pipes.

### <a name="val-fileid"></a>`fileId`

```sml
val fileId : OS.FileSys.file_id Arb.arb
```

The arbitrary of file ids: that of a file in a scratch directory,
removed when the case is over.

### <a name="val-syserror"></a>`syserror`

```sml
val syserror : OS.syserror Arb.arb
```

The arbitrary of the system's errors: each that [`Posix.Error`](../../../basis/str/Posix.Error.md) names,
`acces` the simplest.

### <a name="val-filedesc"></a>`fileDesc`

```sml
val fileDesc : Posix.FileSys.file_desc Arb.arb
```

The arbitrary of Posix file descriptors: the read end of a pipe, closed
when the case is over.

### <a name="val-pid"></a>`pid`

```sml
val pid : Posix.Process.pid Arb.arb
```

The arbitrary of process ids: the process's own and its parent's.

### <a name="val-signal"></a>`signal`

```sml
val signal : Posix.Signal.signal Arb.arb
```

The arbitrary of signals: each that [`Posix.Signal`](../../../basis/str/Posix.Signal.md) names.

### <a name="val-uid"></a>`uid`

```sml
val uid : Posix.ProcEnv.uid Arb.arb
```

The arbitrary of user ids: the process's own and 0.

### <a name="val-gid"></a>`gid`

```sml
val gid : Posix.ProcEnv.gid Arb.arb
```

The arbitrary of group ids: the process's own and 0.

### <a name="val-speed"></a>`speed`

```sml
val speed : Posix.TTY.speed Arb.arb
```

The arbitrary of line speeds: each that [`Posix.TTY`](../../../basis/str/Posix.TTY.md) names.

### <a name="val-termios"></a>`termios`

```sml
val termios : Posix.TTY.termios Arb.arb
```

The arbitrary of terminal settings: flags from drawn words, control
characters drawn for every index, and speeds of [`speed`](#val-speed).

### <a name="val-termiosfields"></a>`termiosFields`

```sml
val termiosFields : {iflag : Posix.TTY.I.flags, oflag : Posix.TTY.O.flags, cflag : Posix.TTY.C.flags,
                     lflag : Posix.TTY.L.flags, cc : Posix.TTY.V.cc, ispeed : Posix.TTY.speed,
                     ospeed : Posix.TTY.speed} Arb.arb
```

The arbitrary of the records of the fields of terminal settings, as
[`Posix.TTY.fieldsOf`](../../../basis/sig/POSIX_TTY.md#val-fieldsof) gives them, drawn as [`termios`](#val-termios) draws settings.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-termiosfields.iflag"></a>`iflag` | `Posix.TTY.I.flags` |  |
| <a name="fld-termiosfields.oflag"></a>`oflag` | `Posix.TTY.O.flags` |  |
| <a name="fld-termiosfields.cflag"></a>`cflag` | `Posix.TTY.C.flags` |  |
| <a name="fld-termiosfields.lflag"></a>`lflag` | `Posix.TTY.L.flags` |  |
| <a name="fld-termiosfields.cc"></a>`cc` | `Posix.TTY.V.cc` |  |
| <a name="fld-termiosfields.ispeed"></a>`ispeed` | `Posix.TTY.speed` |  |
| <a name="fld-termiosfields.ospeed"></a>`ospeed` | `Posix.TTY.speed` |  |

### <a name="val-whence"></a>`whence`

```sml
val whence : Posix.IO.whence Arb.arb
```

The arbitrary of the origins of a seek, [`Posix.IO.SEEK_SET`](../../../basis/sig/POSIX_IO.md#con-seek_set) the
simplest.

### <a name="val-locktype"></a>`lockType`

```sml
val lockType : Posix.IO.lock_type Arb.arb
```

The arbitrary of kinds of lock, [`Posix.IO.F_RDLCK`](../../../basis/sig/POSIX_IO.md#con-f_rdlck) the simplest.

### <a name="val-addrfamily"></a>`addrFamily`

```sml
val addrFamily : Socket.AF.addr_family Arb.arb
```

The arbitrary of address families: each of `Socket.AF.list ()`.

### <a name="val-socktype"></a>`sockType`

```sml
val sockType : Socket.SOCK.sock_type Arb.arb
```

The arbitrary of socket types: each of `Socket.SOCK.list ()`.

### <a name="val-inetstreamsock"></a>`inetStreamSock`

```sml
val inetStreamSock : unit -> 'mode INetSock.stream_sock Arb.arb
```

`inetStreamSock ()` is the arbitrary of new TCP sockets over IPv4, closed
when the case is over.

### <a name="val-inaddr"></a>`inAddr`

```sml
val inAddr : NetHostDB.in_addr Arb.arb
```

The arbitrary of IPv4 addresses: four drawn bytes.

### <a name="val-hostentry"></a>`hostEntry`

```sml
val hostEntry : NetHostDB.entry Arb.arb
```

The arbitrary of host entries: that of `localhost`.

---

<sub>Generated by runedoc from lib/test/property/system\_sig.sml; do not edit.</sub>
