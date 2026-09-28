# structure SystemArb

[Property testing](../README.md) &rsaquo; Property testing &rsaquo; [Structures](../structures.md) &rsaquo; **SystemArb**

|  |  |
| --- | --- |
| Signature | [`SYSTEM_ARB`](../sig/SYSTEM_ARB.md) |
| Status | required |
| Members | 33 |
| Tests | not listed |
| Source | [lib/test/property/system.sml](../../../../../lib/test/property/system.sml) |

## Synopsis

```sml
structure SystemArb :> SYSTEM_ARB
```

## Members

What each means is on [`SYSTEM_ARB`](../sig/SYSTEM_ARB.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| val | [`addrFamily`](../sig/SYSTEM_ARB.md#val-addrfamily) | `{co : NetHostDB.addr_family -> Word64.word, eq : (NetHostDB.addr_family * NetHostDB.addr_family -> bool) option, gen : NetHostDB.addr_family Gen.gen, show : NetHostDB.addr_family -> string}` |
| val | [`binInstream`](../sig/SYSTEM_ARB.md#val-bininstream) | `{co : BinIO.instream -> Word64.word, eq : (BinIO.instream * BinIO.instream -> bool) option, gen : BinIO.instream Gen.gen, show : BinIO.instream -> string}` |
| val | [`binOutstream`](../sig/SYSTEM_ARB.md#val-binoutstream) | `{co : BinIO.StreamIO.outstream -> Word64.word, eq : (BinIO.StreamIO.outstream * BinIO.StreamIO.outstream -> bool) option, gen : BinIO.StreamIO.outstream Gen.gen, show : BinIO.StreamIO.outstream -> string}` |
| val | [`binStreamInstream`](../sig/SYSTEM_ARB.md#val-binstreaminstream) | `{co : BinIO.StreamIO.instream -> Word64.word, eq : (BinIO.StreamIO.instream * BinIO.StreamIO.instream -> bool) option, gen : BinIO.StreamIO.instream Gen.gen, show : BinIO.StreamIO.instream -> string}` |
| val | [`binWriter`](../sig/SYSTEM_ARB.md#val-binwriter) | `{co : BinPrimIO.writer -> Word64.word, eq : (BinPrimIO.writer * BinPrimIO.writer -> bool) option, gen : BinPrimIO.writer Gen.gen, show : BinPrimIO.writer -> string}` |
| val | [`fileDesc`](../sig/SYSTEM_ARB.md#val-filedesc) | `{co : Posix.ProcEnv.file_desc -> Word64.word, eq : (Posix.ProcEnv.file_desc * Posix.ProcEnv.file_desc -> bool) option, gen : Posix.ProcEnv.file_desc Gen.gen, show : Posix.ProcEnv.file_desc -> string}` |
| val | [`fileId`](../sig/SYSTEM_ARB.md#val-fileid) | `{co : OS.FileSys.file_id -> Word64.word, eq : (OS.FileSys.file_id * OS.FileSys.file_id -> bool) option, gen : OS.FileSys.file_id Gen.gen, show : OS.FileSys.file_id -> string}` |
| val | [`gid`](../sig/SYSTEM_ARB.md#val-gid) | `{co : Posix.ProcEnv.gid -> Word64.word, eq : (Posix.ProcEnv.gid * Posix.ProcEnv.gid -> bool) option, gen : Posix.ProcEnv.gid Gen.gen, show : Posix.ProcEnv.gid -> string}` |
| val | [`hostEntry`](../sig/SYSTEM_ARB.md#val-hostentry) | `{co : NetHostDB.entry -> Word64.word, eq : (NetHostDB.entry * NetHostDB.entry -> bool) option, gen : NetHostDB.entry Gen.gen, show : NetHostDB.entry -> string}` |
| val | [`inAddr`](../sig/SYSTEM_ARB.md#val-inaddr) | `{co : NetHostDB.in_addr -> Word64.word, eq : (NetHostDB.in_addr * NetHostDB.in_addr -> bool) option, gen : NetHostDB.in_addr Gen.gen, show : NetHostDB.in_addr -> string}` |
| val | [`inetStreamSock`](../sig/SYSTEM_ARB.md#val-inetstreamsock) | `unit -> {co : (inet', 'a stream') Socket.sock -> Word64.word, eq : ((inet', 'a stream') Socket.sock * (inet', 'a stream') Socket.sock -> bool) option, gen : (inet', 'a stream') Socket.sock Gen.gen, show : (inet', 'a stream') Socket.sock -> string}` |
| val | [`iodesc`](../sig/SYSTEM_ARB.md#val-iodesc) | `{co : OS.IO.iodesc -> Word64.word, eq : (OS.IO.iodesc * OS.IO.iodesc -> bool) option, gen : OS.IO.iodesc Gen.gen, show : OS.IO.iodesc -> string}` |
| val | [`lockType`](../sig/SYSTEM_ARB.md#val-locktype) | `{co : Posix.IO.lock_type -> Word64.word, eq : (Posix.IO.lock_type * Posix.IO.lock_type -> bool) option, gen : Posix.IO.lock_type Gen.gen, show : Posix.IO.lock_type -> string}` |
| val | [`pid`](../sig/SYSTEM_ARB.md#val-pid) | `{co : Posix.Process.pid -> Word64.word, eq : (Posix.Process.pid * Posix.Process.pid -> bool) option, gen : Posix.Process.pid Gen.gen, show : Posix.Process.pid -> string}` |
| val | [`pollDesc`](../sig/SYSTEM_ARB.md#val-polldesc) | `{co : OS.IO.poll_desc -> Word64.word, eq : (OS.IO.poll_desc * OS.IO.poll_desc -> bool) option, gen : OS.IO.poll_desc Gen.gen, show : OS.IO.poll_desc -> string}` |
| val | [`signal`](../sig/SYSTEM_ARB.md#val-signal) | `{co : Unix.signal -> Word64.word, eq : (Unix.signal * Unix.signal -> bool) option, gen : Unix.signal Gen.gen, show : Unix.signal -> string}` |
| val | [`sockType`](../sig/SYSTEM_ARB.md#val-socktype) | `{co : Socket.SOCK.sock_type -> Word64.word, eq : (Socket.SOCK.sock_type * Socket.SOCK.sock_type -> bool) option, gen : Socket.SOCK.sock_type Gen.gen, show : Socket.SOCK.sock_type -> string}` |
| val | [`speed`](../sig/SYSTEM_ARB.md#val-speed) | `{co : Posix.TTY.speed -> Word64.word, eq : (Posix.TTY.speed * Posix.TTY.speed -> bool) option, gen : Posix.TTY.speed Gen.gen, show : Posix.TTY.speed -> string}` |
| val | [`syserror`](../sig/SYSTEM_ARB.md#val-syserror) | `{co : OS.syserror -> Word64.word, eq : (OS.syserror * OS.syserror -> bool) option, gen : OS.syserror Gen.gen, show : OS.syserror -> string}` |
| val | [`termios`](../sig/SYSTEM_ARB.md#val-termios) | `{co : Posix.TTY.termios -> Word64.word, eq : (Posix.TTY.termios * Posix.TTY.termios -> bool) option, gen : Posix.TTY.termios Gen.gen, show : Posix.TTY.termios -> string}` |
| val | [`termiosFields`](../sig/SYSTEM_ARB.md#val-termiosfields) | `{co : {cc : Posix.TTY.V.cc, cflag : Posix.TTY.C.flags, iflag : Posix.TTY.I.flags, ispeed : Posix.TTY.speed, lflag : Posix.TTY.L.flags, oflag : Posix.TTY.O.flags, ospeed : Posix.TTY.speed} -> Word64.word, eq : ({cc : Posix.TTY.V.cc, cflag : Posix.TTY.C.flags, iflag : Posix.TTY.I.flags, ispeed : Posix.TTY.speed, lflag : Posix.TTY.L.flags, oflag : Posix.TTY.O.flags, ospeed : Posix.TTY.speed} * {cc : Posix.TTY.V.cc, cflag : Posix.TTY.C.flags, iflag : Posix.TTY.I.flags, ispeed : Posix.TTY.speed, lflag : Posix.TTY.L.flags, oflag : Posix.TTY.O.flags, ospeed : Posix.TTY.speed} -> bool) option, gen : {cc : Posix.TTY.V.cc, cflag : Posix.TTY.C.flags, iflag : Posix.TTY.I.flags, ispeed : Posix.TTY.speed, lflag : Posix.TTY.L.flags, oflag : Posix.TTY.O.flags, ospeed : Posix.TTY.speed} Gen.gen, show : {cc : Posix.TTY.V.cc, cflag : Posix.TTY.C.flags, iflag : Posix.TTY.I.flags, ispeed : Posix.TTY.speed, lflag : Posix.TTY.L.flags, oflag : Posix.TTY.O.flags, ospeed : Posix.TTY.speed} -> string}` |
| val | [`textInstream`](../sig/SYSTEM_ARB.md#val-textinstream) | `{co : TextIO.instream -> Word64.word, eq : (TextIO.instream * TextIO.instream -> bool) option, gen : TextIO.instream Gen.gen, show : TextIO.instream -> string}` |
| val | [`textOutstream`](../sig/SYSTEM_ARB.md#val-textoutstream) | `{co : TextIO.StreamIO.outstream -> Word64.word, eq : (TextIO.StreamIO.outstream * TextIO.StreamIO.outstream -> bool) option, gen : TextIO.StreamIO.outstream Gen.gen, show : TextIO.StreamIO.outstream -> string}` |
| val | [`textPos`](../sig/SYSTEM_ARB.md#val-textpos) | `{co : TextPrimIO.pos -> Word64.word, eq : (TextPrimIO.pos * TextPrimIO.pos -> bool) option, gen : TextPrimIO.pos Gen.gen, show : TextPrimIO.pos -> string}` |
| val | [`textStreamInstream`](../sig/SYSTEM_ARB.md#val-textstreaminstream) | `{co : TextIO.StreamIO.instream -> Word64.word, eq : (TextIO.StreamIO.instream * TextIO.StreamIO.instream -> bool) option, gen : TextIO.StreamIO.instream Gen.gen, show : TextIO.StreamIO.instream -> string}` |
| val | [`textWriter`](../sig/SYSTEM_ARB.md#val-textwriter) | `{co : TextPrimIO.writer -> Word64.word, eq : (TextPrimIO.writer * TextPrimIO.writer -> bool) option, gen : TextPrimIO.writer Gen.gen, show : TextPrimIO.writer -> string}` |
| val | [`ttyCc`](../sig/SYSTEM_ARB.md#val-ttycc) | `{co : Posix.TTY.V.cc -> Word64.word, eq : (Posix.TTY.V.cc * Posix.TTY.V.cc -> bool) option, gen : Posix.TTY.V.cc Gen.gen, show : Posix.TTY.V.cc -> string}` |
| val | [`ttyCflags`](../sig/SYSTEM_ARB.md#val-ttycflags) | `{co : Posix.TTY.C.flags -> Word64.word, eq : (Posix.TTY.C.flags * Posix.TTY.C.flags -> bool) option, gen : Posix.TTY.C.flags Gen.gen, show : Posix.TTY.C.flags -> string}` |
| val | [`ttyIflags`](../sig/SYSTEM_ARB.md#val-ttyiflags) | `{co : Posix.TTY.I.flags -> Word64.word, eq : (Posix.TTY.I.flags * Posix.TTY.I.flags -> bool) option, gen : Posix.TTY.I.flags Gen.gen, show : Posix.TTY.I.flags -> string}` |
| val | [`ttyLflags`](../sig/SYSTEM_ARB.md#val-ttylflags) | `{co : Posix.TTY.L.flags -> Word64.word, eq : (Posix.TTY.L.flags * Posix.TTY.L.flags -> bool) option, gen : Posix.TTY.L.flags Gen.gen, show : Posix.TTY.L.flags -> string}` |
| val | [`ttyOflags`](../sig/SYSTEM_ARB.md#val-ttyoflags) | `{co : Posix.TTY.O.flags -> Word64.word, eq : (Posix.TTY.O.flags * Posix.TTY.O.flags -> bool) option, gen : Posix.TTY.O.flags Gen.gen, show : Posix.TTY.O.flags -> string}` |
| val | [`uid`](../sig/SYSTEM_ARB.md#val-uid) | `{co : Posix.ProcEnv.uid -> Word64.word, eq : (Posix.ProcEnv.uid * Posix.ProcEnv.uid -> bool) option, gen : Posix.ProcEnv.uid Gen.gen, show : Posix.ProcEnv.uid -> string}` |
| val | [`whence`](../sig/SYSTEM_ARB.md#val-whence) | `{co : Posix.IO.whence -> Word64.word, eq : (Posix.IO.whence * Posix.IO.whence -> bool) option, gen : Posix.IO.whence Gen.gen, show : Posix.IO.whence -> string}` |

---

<sub>Generated by runedoc from lib/test/property/system.sml; do not edit.</sub>
