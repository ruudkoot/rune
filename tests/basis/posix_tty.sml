(* requires: Posix OS *)
(* Posix.TTY (signature POSIX_TTY), after
   https://smlfamily.github.io/Basis/posix-tty.html, as far as it can be
   checked without a terminal: the tests run with /dev/null as standard
   input and no terminal among their descriptors. The operations on
   termios values and control characters are pure; those of TC fail on a
   descriptor that is not a terminal (POSIX: ENOTTY), with OS.SysErr. The
   BIT_FLAGS operations of I, O, C and L are in posix_bitflags.sml; here,
   the flags that they name. *)
structure TestPosixTTY =
struct
  structure Y = Posix.TTY
  val eqB = T.eq T.bool
  val eqC = T.eq T.char
  val isSysErr = fn OS.SysErr _ => true | _ => false
  fun distinct [] = true
    | distinct (x :: r) = not (List.exists (fn y => y = x) r) andalso distinct r

  (* ---- V: "Indices for the special control characters ... These are the
     indices used in the functions cc and sub"; "valid indices range from 0
     to nccs-1" ---- *)
  fun index (label, i) = eqB (label, true, fn () => 0 <= i andalso i < Y.V.nccs)
  val () = index ("Posix.TTY.V.eof/index", Y.V.eof)
  val () = index ("Posix.TTY.V.eol/index", Y.V.eol)
  val () = index ("Posix.TTY.V.erase/index", Y.V.erase)
  val () = index ("Posix.TTY.V.intr/index", Y.V.intr)
  val () = index ("Posix.TTY.V.kill/index", Y.V.kill)
  val () = index ("Posix.TTY.V.min/index", Y.V.min)
  val () = index ("Posix.TTY.V.quit/index", Y.V.quit)
  val () = index ("Posix.TTY.V.susp/index", Y.V.susp)
  val () = index ("Posix.TTY.V.time/index", Y.V.time)
  val () = index ("Posix.TTY.V.start/index", Y.V.start)
  val () = index ("Posix.TTY.V.stop/index", Y.V.stop)
  val () = eqB ("Posix.TTY.V.nccs/positive", true, fn () => Y.V.nccs >= 11)
  (* POSIX lets MIN share its place with EOF and TIME with EOL (they are
     used in different modes); the others differ. *)
  val () = eqB ("Posix.TTY.V.eof/distinct", true,
                fn () => distinct [Y.V.eof, Y.V.eol, Y.V.erase, Y.V.intr, Y.V.kill, Y.V.quit, Y.V.susp, Y.V.start, Y.V.stop]
                         andalso distinct [Y.V.min, Y.V.time, Y.V.erase, Y.V.intr, Y.V.kill, Y.V.quit, Y.V.susp, Y.V.start, Y.V.stop])
  (* "cc l creates a value of type cc, mapping an index to its paired
     character. Unspecified indices are associated with #"\000"." *)
  val () = eqC ("Posix.TTY.V.cc/given", #"\^D", fn () => Y.V.sub (Y.V.cc [(Y.V.eof, #"\^D")], Y.V.eof))
  val () = eqB ("Posix.TTY.V.cc/unspecified-nul", true,
                fn () => let val c = Y.V.cc [(Y.V.eof, #"\^D")]
                         in List.all (fn i => i = Y.V.eof orelse Y.V.sub (c, i) = #"\000") (List.tabulate (Y.V.nccs, fn i => i)) end)
  val () = eqB ("Posix.TTY.V.cc/empty", true,
                fn () => let val c = Y.V.cc [] in List.all (fn i => Y.V.sub (c, i) = #"\000") (List.tabulate (Y.V.nccs, fn i => i)) end)
  val () = eqC ("Posix.TTY.V.cc/several", #"\^C",
                fn () => Y.V.sub (Y.V.cc [(Y.V.eof, #"\^D"), (Y.V.intr, #"\^C"), (Y.V.erase, #"\127")], Y.V.intr))
  (* "update (cs, l) returns a copy of cs, but with the new mappings
     specified by l overwriting the original mappings." *)
  val () = T.eq (T.list T.char) ("Posix.TTY.V.update/overwrites", [#"\^Z", #"\^C", #"\^D"],
                fn () => let
                           val c = Y.V.cc [(Y.V.eof, #"\^D"), (Y.V.intr, #"\^C")]
                           val c' = Y.V.update (c, [(Y.V.eof, #"\^Z")])
                         in [Y.V.sub (c', Y.V.eof), Y.V.sub (c', Y.V.intr), Y.V.sub (c, Y.V.eof)] end)
  val () = eqC ("Posix.TTY.V.update/empty-list", #"\^D",
                fn () => Y.V.sub (Y.V.update (Y.V.cc [(Y.V.eof, #"\^D")], []), Y.V.eof))
  (* sub "raises Subscript if i is negative or i >= nccs" *)
  val () = eqC ("Posix.TTY.V.sub/last", #"x", fn () => Y.V.sub (Y.V.cc [(Y.V.nccs - 1, #"x")], Y.V.nccs - 1))
  val () = T.raises ("Posix.TTY.V.sub/negative", T.isSubscript, fn () => Y.V.sub (Y.V.cc [], ~1))
  val () = T.raises ("Posix.TTY.V.sub/nccs", T.isSubscript, fn () => Y.V.sub (Y.V.cc [], Y.V.nccs))

  (* ---- the named flags: POSIX gives each of them its own bits, which all
     ("the union of all flags") has; csize "is the union of cs5, cs6, cs7,
     and cs8". Their bits are compared with SysWord operations, not with
     allSet and anySet, which posix_bitflags.sml checks. ---- *)
  fun within (f, all) = SysWord.andb (f, all) = f
  fun disjointW l =
    let fun go [] = true
          | go (x :: r) = List.all (fn y => SysWord.andb (x, y) = 0w0) r andalso go r
    in go l end
  val iFlags = [Y.I.brkint, Y.I.icrnl, Y.I.ignbrk, Y.I.igncr, Y.I.ignpar, Y.I.inlcr, Y.I.inpck,
                Y.I.istrip, Y.I.ixoff, Y.I.ixon, Y.I.parmrk]
  fun iFlag (label, f) = eqB (label, true, fn () => Y.I.toWord f <> 0w0 andalso within (Y.I.toWord f, Y.I.toWord Y.I.all))
  val () = iFlag ("Posix.TTY.I.brkint/own-bit", Y.I.brkint)
  val () = iFlag ("Posix.TTY.I.icrnl/own-bit", Y.I.icrnl)
  val () = iFlag ("Posix.TTY.I.ignbrk/own-bit", Y.I.ignbrk)
  val () = iFlag ("Posix.TTY.I.igncr/own-bit", Y.I.igncr)
  val () = iFlag ("Posix.TTY.I.ignpar/own-bit", Y.I.ignpar)
  val () = iFlag ("Posix.TTY.I.inlcr/own-bit", Y.I.inlcr)
  val () = iFlag ("Posix.TTY.I.inpck/own-bit", Y.I.inpck)
  val () = iFlag ("Posix.TTY.I.istrip/own-bit", Y.I.istrip)
  val () = iFlag ("Posix.TTY.I.ixoff/own-bit", Y.I.ixoff)
  val () = iFlag ("Posix.TTY.I.ixon/own-bit", Y.I.ixon)
  val () = iFlag ("Posix.TTY.I.parmrk/own-bit", Y.I.parmrk)
  val () = eqB ("Posix.TTY.I.brkint/disjoint", true, fn () => disjointW (List.map Y.I.toWord iFlags))
  val () = eqB ("Posix.TTY.O.opost/own-bit", true, fn () => Y.O.toWord Y.O.opost <> 0w0 andalso within (Y.O.toWord Y.O.opost, Y.O.toWord Y.O.all))
  val cFlags = [Y.C.clocal, Y.C.cread, Y.C.csize, Y.C.cstopb, Y.C.hupcl, Y.C.parenb, Y.C.parodd]
  fun cFlag (label, f) = eqB (label, true, fn () => Y.C.toWord f <> 0w0 andalso within (Y.C.toWord f, Y.C.toWord Y.C.all))
  val () = cFlag ("Posix.TTY.C.clocal/own-bit", Y.C.clocal)
  val () = cFlag ("Posix.TTY.C.cread/own-bit", Y.C.cread)
  val () = cFlag ("Posix.TTY.C.csize/own-bit", Y.C.csize)
  val () = cFlag ("Posix.TTY.C.cstopb/own-bit", Y.C.cstopb)
  val () = cFlag ("Posix.TTY.C.hupcl/own-bit", Y.C.hupcl)
  val () = cFlag ("Posix.TTY.C.parenb/own-bit", Y.C.parenb)
  val () = cFlag ("Posix.TTY.C.parodd/own-bit", Y.C.parodd)
  val () = eqB ("Posix.TTY.C.clocal/disjoint", true, fn () => disjointW (List.map Y.C.toWord cFlags))
  val () = eqB ("Posix.TTY.C.csize/union-of-sizes", true,
                fn () => Y.C.flags [Y.C.cs5, Y.C.cs6, Y.C.cs7, Y.C.cs8] = Y.C.csize)
  fun inSize (label, f) = eqB (label, true, fn () => within (Y.C.toWord f, Y.C.toWord Y.C.csize))
  val () = inSize ("Posix.TTY.C.cs5/in-csize", Y.C.cs5)
  val () = inSize ("Posix.TTY.C.cs6/in-csize", Y.C.cs6)
  val () = inSize ("Posix.TTY.C.cs7/in-csize", Y.C.cs7)
  val () = inSize ("Posix.TTY.C.cs8/in-csize", Y.C.cs8)
  val () = eqB ("Posix.TTY.C.cs8/distinct-sizes", true, fn () => distinct (List.map Y.C.toWord [Y.C.cs5, Y.C.cs6, Y.C.cs7, Y.C.cs8]))
  val lFlags = [Y.L.echo, Y.L.echoe, Y.L.echok, Y.L.echonl, Y.L.icanon, Y.L.iexten, Y.L.isig, Y.L.noflsh, Y.L.tostop]
  fun lFlag (label, f) = eqB (label, true, fn () => Y.L.toWord f <> 0w0 andalso within (Y.L.toWord f, Y.L.toWord Y.L.all))
  val () = lFlag ("Posix.TTY.L.echo/own-bit", Y.L.echo)
  val () = lFlag ("Posix.TTY.L.echoe/own-bit", Y.L.echoe)
  val () = lFlag ("Posix.TTY.L.echok/own-bit", Y.L.echok)
  val () = lFlag ("Posix.TTY.L.echonl/own-bit", Y.L.echonl)
  val () = lFlag ("Posix.TTY.L.icanon/own-bit", Y.L.icanon)
  val () = lFlag ("Posix.TTY.L.iexten/own-bit", Y.L.iexten)
  val () = lFlag ("Posix.TTY.L.isig/own-bit", Y.L.isig)
  val () = lFlag ("Posix.TTY.L.noflsh/own-bit", Y.L.noflsh)
  val () = lFlag ("Posix.TTY.L.tostop/own-bit", Y.L.tostop)
  val () = eqB ("Posix.TTY.L.echo/disjoint", true, fn () => disjointW (List.map Y.L.toWord lFlags))

  (* ---- speeds: "b1200 is 1200 baud, b9600 is 9600 baud, etc. The value b0
     indicates hang up"; compareSpeed compares the baud rates ---- *)
  val speeds = [Y.b0, Y.b50, Y.b75, Y.b110, Y.b134, Y.b150, Y.b200, Y.b300, Y.b600, Y.b1200,
                Y.b1800, Y.b2400, Y.b4800, Y.b9600, Y.b19200, Y.b38400]
  fun rank (label, s, n) = T.eq T.int (label, n, fn () => List.length (List.filter (fn x => Y.compareSpeed (x, s) = LESS) speeds))
  val () = rank ("Posix.TTY.b0/slowest", Y.b0, 0)
  val () = rank ("Posix.TTY.b50/rank", Y.b50, 1)
  val () = rank ("Posix.TTY.b75/rank", Y.b75, 2)
  val () = rank ("Posix.TTY.b110/rank", Y.b110, 3)
  val () = rank ("Posix.TTY.b134/rank", Y.b134, 4)
  val () = rank ("Posix.TTY.b150/rank", Y.b150, 5)
  val () = rank ("Posix.TTY.b200/rank", Y.b200, 6)
  val () = rank ("Posix.TTY.b300/rank", Y.b300, 7)
  val () = rank ("Posix.TTY.b600/rank", Y.b600, 8)
  val () = rank ("Posix.TTY.b1200/rank", Y.b1200, 9)
  val () = rank ("Posix.TTY.b1800/rank", Y.b1800, 10)
  val () = rank ("Posix.TTY.b2400/rank", Y.b2400, 11)
  val () = rank ("Posix.TTY.b4800/rank", Y.b4800, 12)
  val () = rank ("Posix.TTY.b9600/rank", Y.b9600, 13)
  val () = rank ("Posix.TTY.b19200/rank", Y.b19200, 14)
  val () = rank ("Posix.TTY.b38400/fastest", Y.b38400, 15)
  val () = T.eq (T.list T.order) ("Posix.TTY.compareSpeed/basic", [LESS, EQUAL, GREATER],
                                  fn () => [Y.compareSpeed (Y.b1200, Y.b9600), Y.compareSpeed (Y.b9600, Y.b9600),
                                            Y.compareSpeed (Y.b38400, Y.b0)])
  val () = eqB ("Posix.TTY.compareSpeed/antisymmetric", true,
                fn () => List.all (fn a => List.all (fn b => Y.compareSpeed (a, b) = (case Y.compareSpeed (b, a) of
                                                                                          LESS => GREATER | EQUAL => EQUAL | GREATER => LESS))
                                                    speeds) speeds)
  val () = eqB ("Posix.TTY.speedToWord/distinct", true, fn () => distinct (List.map Y.speedToWord speeds))
  val () = eqB ("Posix.TTY.wordToSpeed/of-speedToWord", true,
                fn () => List.all (fn s => Y.wordToSpeed (Y.speedToWord s) = s) speeds)
  (* "No checking is performed by wordToSpeed" *)
  val () = eqB ("Posix.TTY.wordToSpeed/no-check", true,
                fn () => Y.speedToWord (Y.wordToSpeed 0wx7777) = 0wx7777)

  (* ---- termios, fieldsOf and the projections ---- *)
  val cc0 = Y.V.cc [(Y.V.eof, #"\^D"), (Y.V.intr, #"\^C")]
  fun sample () =
    Y.termios {iflag = Y.I.flags [Y.I.icrnl, Y.I.ixon], oflag = Y.O.opost, cflag = Y.C.flags [Y.C.cs8, Y.C.cread],
               lflag = Y.L.flags [Y.L.echo, Y.L.icanon], cc = cc0, ispeed = Y.b9600, ospeed = Y.b38400}
  fun sameCC (a, b) = List.all (fn i => Y.V.sub (a, i) = Y.V.sub (b, i)) (List.tabulate (Y.V.nccs, fn i => i))
  val () = eqB ("Posix.TTY.termios/fieldsOf", true,
                fn () => let val {iflag, oflag, cflag, lflag, cc, ispeed, ospeed} = Y.fieldsOf (sample ())
                         in
                           iflag = Y.I.flags [Y.I.icrnl, Y.I.ixon] andalso oflag = Y.O.opost
                           andalso cflag = Y.C.flags [Y.C.cs8, Y.C.cread] andalso lflag = Y.L.flags [Y.L.echo, Y.L.icanon]
                           andalso sameCC (cc, cc0) andalso ispeed = Y.b9600 andalso ospeed = Y.b38400
                         end)
  (* fieldsOf "returns a concrete representation of a termios value", from
     which termios makes the same value again. *)
  val () = eqB ("Posix.TTY.fieldsOf/termios", true,
                fn () => let val t = Y.termios (Y.fieldsOf (sample ()))
                         in
                           Y.getiflag t = Y.getiflag (sample ()) andalso Y.getoflag t = Y.getoflag (sample ())
                           andalso Y.getcflag t = Y.getcflag (sample ()) andalso Y.getlflag t = Y.getlflag (sample ())
                           andalso sameCC (Y.getcc t, cc0) andalso Y.CF.getispeed t = Y.b9600 andalso Y.CF.getospeed t = Y.b38400
                         end)
  val () = eqB ("Posix.TTY.getiflag/sample", true, fn () => Y.getiflag (sample ()) = Y.I.flags [Y.I.icrnl, Y.I.ixon])
  val () = eqB ("Posix.TTY.getoflag/sample", true, fn () => Y.getoflag (sample ()) = Y.O.opost)
  val () = eqB ("Posix.TTY.getcflag/sample", true, fn () => Y.getcflag (sample ()) = Y.C.flags [Y.C.cs8, Y.C.cread])
  val () = eqB ("Posix.TTY.getlflag/sample", true, fn () => Y.getlflag (sample ()) = Y.L.flags [Y.L.echo, Y.L.icanon])
  val () = eqB ("Posix.TTY.getcc/sample", true, fn () => sameCC (Y.getcc (sample ()), cc0))

  (* ---- CF: "These return a copy of t, but with the output (input) speed
     set to speed." ---- *)
  val () = eqB ("Posix.TTY.CF.getospeed/sample", true, fn () => Y.CF.getospeed (sample ()) = Y.b38400)
  val () = eqB ("Posix.TTY.CF.getispeed/sample", true, fn () => Y.CF.getispeed (sample ()) = Y.b9600)
  val () = eqB ("Posix.TTY.CF.setospeed/copy", true,
                fn () => let val t = sample () val t' = Y.CF.setospeed (t, Y.b1200)
                         in Y.CF.getospeed t' = Y.b1200 andalso Y.CF.getispeed t' = Y.b9600
                            andalso Y.CF.getospeed t = Y.b38400 andalso Y.getiflag t' = Y.getiflag t end)
  val () = eqB ("Posix.TTY.CF.setispeed/copy", true,
                fn () => let val t = sample () val t' = Y.CF.setispeed (t, Y.b300)
                         in Y.CF.getispeed t' = Y.b300 andalso Y.CF.getospeed t' = Y.b38400
                            andalso Y.CF.getispeed t = Y.b9600 andalso Y.getlflag t' = Y.getlflag t end)

  (* ---- TC ---- *)
  val () = eqB ("Posix.TTY.TC.sanow/distinct", true, fn () => distinct [Y.TC.sanow, Y.TC.sadrain, Y.TC.saflush])
  val () = eqB ("Posix.TTY.TC.sadrain/not-sanow", true, fn () => Y.TC.sadrain <> Y.TC.sanow)
  val () = eqB ("Posix.TTY.TC.saflush/not-sadrain", true, fn () => Y.TC.saflush <> Y.TC.sadrain)
  val () = eqB ("Posix.TTY.TC.ooff/distinct", true, fn () => distinct [Y.TC.ooff, Y.TC.oon, Y.TC.ioff, Y.TC.ion])
  val () = eqB ("Posix.TTY.TC.oon/not-ooff", true, fn () => Y.TC.oon <> Y.TC.ooff)
  val () = eqB ("Posix.TTY.TC.ioff/not-ion", true, fn () => Y.TC.ioff <> Y.TC.ion)
  val () = eqB ("Posix.TTY.TC.ion/not-oon", true, fn () => Y.TC.ion <> Y.TC.oon)
  val () = eqB ("Posix.TTY.TC.iflush/distinct", true, fn () => distinct [Y.TC.iflush, Y.TC.oflush, Y.TC.ioflush])
  val () = eqB ("Posix.TTY.TC.oflush/not-iflush", true, fn () => Y.TC.oflush <> Y.TC.iflush)
  val () = eqB ("Posix.TTY.TC.ioflush/not-oflush", true, fn () => Y.TC.ioflush <> Y.TC.oflush)
  (* On a descriptor that is not a terminal. *)
  val stdin = Posix.FileSys.wordToFD 0w0
  val () = T.raises ("Posix.TTY.TC.getattr/not-a-terminal", isSysErr, fn () => Y.TC.getattr stdin)
  val () = T.raises ("Posix.TTY.TC.setattr/not-a-terminal", isSysErr, fn () => Y.TC.setattr (stdin, Y.TC.sanow, sample ()))
  val () = T.raises ("Posix.TTY.TC.sendbreak/not-a-terminal", isSysErr, fn () => Y.TC.sendbreak (stdin, 0))
  val () = T.raises ("Posix.TTY.TC.drain/not-a-terminal", isSysErr, fn () => Y.TC.drain stdin)
  val () = T.raises ("Posix.TTY.TC.flush/not-a-terminal", isSysErr, fn () => Y.TC.flush (stdin, Y.TC.ioflush))
  val () = T.raises ("Posix.TTY.TC.flow/not-a-terminal", isSysErr, fn () => Y.TC.flow (stdin, Y.TC.oon))
  val () = T.raises ("Posix.TTY.TC.getattr/bad-descriptor", isSysErr, fn () => Y.TC.getattr (Posix.FileSys.wordToFD 0w1000))
  (*<< pgrp *)
  val () = T.raises ("Posix.TTY.TC.getpgrp/not-a-terminal", isSysErr, fn () => Y.TC.getpgrp stdin)
  val () = T.raises ("Posix.TTY.TC.setpgrp/not-a-terminal", isSysErr,
                     fn () => Y.TC.setpgrp (stdin, Posix.ProcEnv.getpgrp ()))
  (*>> pgrp *)
end
