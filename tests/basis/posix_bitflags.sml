(* requires: Posix SysWord *)
(* uses: spec-sigs/BIT_FLAGS.sml fn/bit_flags_fn.sml *)
(* The substructures of Posix whose signature includes BIT_FLAGS: FileSys.S
   and FileSys.O (https://smlfamily.github.io/Basis/posix-file-sys.html),
   IO.FD and IO.O (posix-io.html), Process.W (posix-process.html) and TTY.I,
   TTY.O, TTY.C and TTY.L (posix-tty.html). The checks, which follow
   https://smlfamily.github.io/Basis/bit-flags.html, are in
   fn/bit_flags_fn.sml; each structure is a section of its own. What the
   named flags mean is checked where they are used (posix_filesys.sml,
   posix_io.sml). *)
structure TestPosixBitFlags =
struct
  (*<< filesys-s *)
  local
    structure S = Posix.FileSys.S
  in
    val namedS = [("irwxu", S.irwxu), ("irusr", S.irusr), ("iwusr", S.iwusr), ("ixusr", S.ixusr),
                  ("irwxg", S.irwxg), ("irgrp", S.irgrp), ("iwgrp", S.iwgrp), ("ixgrp", S.ixgrp),
                  ("irwxo", S.irwxo), ("iroth", S.iroth), ("iwoth", S.iwoth), ("ixoth", S.ixoth),
                  ("isuid", S.isuid), ("isgid", S.isgid)]
  end
  structure FileSysS = TestBitFlagsFn (structure F = Posix.FileSys.S val name = "Posix.FileSys.S" val named = namedS)
  (*>> filesys-s *)

  (*<< filesys-o *)
  local
    structure O = Posix.FileSys.O
  in
    val namedFO = [("append", O.append), ("excl", O.excl), ("noctty", O.noctty),
                   ("nonblock", O.nonblock), ("sync", O.sync), ("trunc", O.trunc)]
  end
  structure FileSysO = TestBitFlagsFn (structure F = Posix.FileSys.O val name = "Posix.FileSys.O" val named = namedFO)
  (*>> filesys-o *)

  (*<< io-fd *)
  structure IOFD = TestBitFlagsFn (structure F = Posix.IO.FD val name = "Posix.IO.FD" val named = [("cloexec", Posix.IO.FD.cloexec)])
  (*>> io-fd *)

  (*<< io-o *)
  local
    structure O = Posix.IO.O
  in
    val namedIO = [("append", O.append), ("nonblock", O.nonblock), ("sync", O.sync)]
  end
  structure IOO = TestBitFlagsFn (structure F = Posix.IO.O val name = "Posix.IO.O" val named = namedIO)
  (*>> io-o *)

  (*<< process-w *)
  structure ProcessW = TestBitFlagsFn (structure F = Posix.Process.W val name = "Posix.Process.W" val named = [("untraced", Posix.Process.W.untraced)])
  (*>> process-w *)

  (*<< tty-i *)
  local
    structure I = Posix.TTY.I
  in
    val namedTI = [("brkint", I.brkint), ("icrnl", I.icrnl), ("ignbrk", I.ignbrk), ("igncr", I.igncr),
                   ("ignpar", I.ignpar), ("inlcr", I.inlcr), ("inpck", I.inpck), ("istrip", I.istrip),
                   ("ixoff", I.ixoff), ("ixon", I.ixon), ("parmrk", I.parmrk)]
  end
  structure TTYI = TestBitFlagsFn (structure F = Posix.TTY.I val name = "Posix.TTY.I" val named = namedTI)
  (*>> tty-i *)

  (*<< tty-o *)
  structure TTYO = TestBitFlagsFn (structure F = Posix.TTY.O val name = "Posix.TTY.O" val named = [("opost", Posix.TTY.O.opost)])
  (*>> tty-o *)

  (*<< tty-c *)
  local
    structure C = Posix.TTY.C
  in
    val namedTC = [("clocal", C.clocal), ("cread", C.cread), ("cs5", C.cs5), ("cs6", C.cs6),
                   ("cs7", C.cs7), ("cs8", C.cs8), ("csize", C.csize), ("cstopb", C.cstopb),
                   ("hupcl", C.hupcl), ("parenb", C.parenb), ("parodd", C.parodd)]
  end
  structure TTYC = TestBitFlagsFn (structure F = Posix.TTY.C val name = "Posix.TTY.C" val named = namedTC)
  (*>> tty-c *)

  (*<< tty-l *)
  local
    structure L = Posix.TTY.L
  in
    val namedTL = [("echo", L.echo), ("echoe", L.echoe), ("echok", L.echok), ("echonl", L.echonl),
                   ("icanon", L.icanon), ("iexten", L.iexten), ("isig", L.isig), ("noflsh", L.noflsh),
                   ("tostop", L.tostop)]
  end
  structure TTYL = TestBitFlagsFn (structure F = Posix.TTY.L val name = "Posix.TTY.L" val named = namedTL)
  (*>> tty-l *)
end
