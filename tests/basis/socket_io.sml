(* requires: Socket INetSock UnixSock NetHostDB Byte *)
(* uses: fn/sockets.sml *)
(* Socket (signature SOCKET): sending and receiving on active stream sockets,
   the blocking and the non-blocking forms, with and without flags. Expected
   values follow https://smlfamily.github.io/Basis/socket.html.

   The pairs are TCP on the loopback interface or Unix-domain stream pairs
   (fn/sockets.sml). A blocking receive is only called when bytes or the end
   of the stream are there to be read, so that nothing waits. Bytes sent in
   one call of at most a few bytes arrive together, and a check that reads
   them without blocking first waits (for at most 5 s) for the socket to be
   readable. Datagrams are in socket_dgram.sml. *)
structure TestSocketIO =
struct
  structure S = Sockets
  val eqS = T.eq T.string
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqOI = T.eq (T.option T.int)
  val eqOS = T.eq (T.option T.string)
  val oob = {don't_route = false, oob = true}
  val dontRoute = {don't_route = true, oob = false}
  val inOob = {peek = false, oob = true}
  fun vtext v = S.text v
  fun vsub (s, i, n) = Word8VectorSlice.slice (S.bytes s, i, SOME n)
  fun asub (s, i, n) = Word8ArraySlice.slice (#1 (Word8ArraySlice.base (S.aslice s)), i, SOME n)

  (*<< send *)
  (* "They return the number of bytes actually sent." *)
  val () = eqI ("Socket.sendVec/count", 5, fn () => S.withTcp (fn (c, _) => Socket.sendVec (c, S.vslice "hello")))
  val () = eqS ("Socket.sendVec/arrives", "hello",
                fn () => S.withTcp (fn (c, s) => (ignore (Socket.sendVec (c, S.vslice "hello")); S.recvAll (s, 5))))
  (* "send the bytes in the slice slice" *)
  val () = eqS ("Socket.sendVec/slice", "3 bcd",
                fn () => S.withTcp (fn (c, s) =>
                           Int.toString (Socket.sendVec (c, vsub ("abcdef", 1, 3))) ^ " " ^ S.recvAll (s, 3)))
  val () = eqI ("Socket.sendVec/empty-slice", 0, fn () => S.withTcp (fn (c, _) => Socket.sendVec (c, S.vslice "")))
  val () = eqS ("Socket.sendVec/unix-pair-both-ways", "ab",
                fn () => S.withStrm (fn (a, b) =>
                           (ignore (Socket.sendVec (a, S.vslice "a")); ignore (Socket.sendVec (b, S.vslice "b"));
                            S.recvAll (b, 1) ^ S.recvAll (a, 1))))
  (* "These functions raise SysErr if sock has been closed." *)
  val () = T.raises ("Socket.sendVec/closed", S.isSysErr, fn () => Socket.sendVec (S.closedTcp (), S.vslice "x"))
  val () = eqI ("Socket.sendArr/count", 5, fn () => S.withTcp (fn (c, _) => Socket.sendArr (c, S.aslice "hello")))
  val () = eqS ("Socket.sendArr/arrives", "hello",
                fn () => S.withTcp (fn (c, s) => (ignore (Socket.sendArr (c, S.aslice "hello")); S.recvAll (s, 5))))
  val () = eqS ("Socket.sendArr/slice", "2 de",
                fn () => S.withStrm (fn (a, b) =>
                           Int.toString (Socket.sendArr (a, asub ("abcdef", 3, 2))) ^ " " ^ S.recvAll (b, 2)))
  val () = eqI ("Socket.sendArr/empty-slice", 0, fn () => S.withTcp (fn (c, _) => Socket.sendArr (c, S.aslice "")))
  val () = T.raises ("Socket.sendArr/closed", S.isSysErr, fn () => Socket.sendArr (S.closedTcp (), S.aslice "x"))

  val () = eqS ("Socket.sendVec'/no-flags", "4 flag",
                fn () => S.withTcp (fn (c, s) =>
                           Int.toString (Socket.sendVec' (c, vsub ("flags", 0, 4), S.noOut)) ^ " " ^ S.recvAll (s, 4)))
  (* "If the don't_route flag is true, the data is sent bypassing the normal
     routing mechanism of the protocol": the loopback interface is at hand *)
  val () = eqS ("Socket.sendVec'/don't_route", "5 local",
                fn () => S.withTcp (fn (c, s) =>
                           Int.toString (Socket.sendVec' (c, S.vslice "local", dontRoute)) ^ " " ^ S.recvAll (s, 5)))
  val () = T.raises ("Socket.sendVec'/closed", S.isSysErr, fn () => Socket.sendVec' (S.closedTcp (), S.vslice "x", S.noOut))
  val () = eqS ("Socket.sendArr'/no-flags", "3 arr",
                fn () => S.withTcp (fn (c, s) =>
                           Int.toString (Socket.sendArr' (c, S.aslice "arr", S.noOut)) ^ " " ^ S.recvAll (s, 3)))
  val () = eqS ("Socket.sendArr'/don't_route", "5 local",
                fn () => S.withTcp (fn (c, s) =>
                           Int.toString (Socket.sendArr' (c, S.aslice "local", dontRoute)) ^ " " ^ S.recvAll (s, 5)))
  val () = T.raises ("Socket.sendArr'/closed", S.isSysErr, fn () => Socket.sendArr' (S.closedTcp (), S.aslice "x", S.noOut))
  (*>> send *)

  (*<< oob *)
  (* "If oob is true, the data is sent out-of-band". TCP sends the last byte
     of such a call as its urgent byte: the other end reads the bytes before
     it, up to the mark, the byte itself with recvVec' and oob, and then what
     follows. The bytes of one call go in one segment, so that once the first
     ones are read the urgent byte is there too; and bytes are sent after it,
     so that the socket is readable while the urgent byte waits (Poly/ML
     5.9.2 waits for that before any receive, oob or not). *)
  fun urgent (sendIt : S.tcp -> int) (receive : S.tcp -> string) : string =
    S.withTcp (fn (c, s) =>
      let
        val n = sendIt c
        val _ = S.send (c, "de")
        val normal = S.recvAll (s, 2)
        val urgentByte = receive s
      in Int.toString n ^ " " ^ normal ^ " " ^ urgentByte ^ " " ^ S.recvAll (s, 2) end)
  fun recvOob s = vtext (Socket.recvVec' (s, 1, inOob))
  val () = eqS ("Socket.sendVec'/oob", "3 ab c de", fn () => urgent (fn c => Socket.sendVec' (c, S.vslice "abc", oob)) recvOob)
  val () = eqS ("Socket.sendArr'/oob", "3 ab c de", fn () => urgent (fn c => Socket.sendArr' (c, S.aslice "abc", oob)) recvOob)
  val () = eqS ("Socket.recvVec'/oob", "3 ab c de",
                fn () => urgent (fn c => Socket.sendVec' (c, S.vslice "abc", oob)) (fn s => vtext (Socket.recvVec' (s, 5, inOob))))
  val () = eqS ("Socket.recvArr'/oob", "3 xy 1 .z. de",
                fn () => urgent (fn c => Socket.sendVec' (c, S.vslice "xyz", oob))
                                (fn s => let val a = S.filled 3
                                         in Int.toString (Socket.recvArr' (s, Word8ArraySlice.slice (a, 1, SOME 1), inOob)) ^ " " ^ S.shown a end))
  (* select: "have an exceptional condition pending" *)
  val () = T.check ("Socket.select/exceptional-condition",
                    fn () => S.withTcp (fn (c, s) =>
                               (ignore (Socket.sendVec' (c, S.vslice "u", oob));
                                case #exs (Socket.select {rds = [], wrs = [], exs = [Socket.sockDesc s], timeout = SOME S.patience}) of
                                  [d] => Socket.sameDesc (d, Socket.sockDesc s)
                                | _ => false)))
  (*>> oob *)

  (*<< recv *)
  (* "receive up to n bytes ... The size of the resulting vector is the number
     of bytes that were successfully received, which may be less than n." *)
  val () = eqS ("Socket.recvVec/at-most-n", "hello| world",
                fn () => S.withTcp (fn (c, s) =>
                           (ignore (S.send (c, "hello world"));
                            if S.readable s then vtext (Socket.recvVec (s, 5)) ^ "|" ^ S.recvAll (s, 6) else "nothing")))
  val () = eqS ("Socket.recvVec/unix", "pair", fn () => S.withStrm (fn (a, b) => (ignore (S.send (a, "pair")); S.recvAll (b, 4))))
  (* "If the connection has been closed at the other end (or if n is 0), then
     the empty vector will be returned." *)
  val () = eqS ("Socket.recvVec/zero", "|kept",
                fn () => S.withTcp (fn (c, s) =>
                           (ignore (S.send (c, "kept"));
                            if S.readable s then vtext (Socket.recvVec (s, 0)) ^ "|" ^ S.recvAll (s, 4) else "nothing")))
  val () = eqS ("Socket.recvVec/end-of-stream", "",
                fn () => S.withTcp (fn (c, s) => (Socket.close c; vtext (Socket.recvVec (s, 10)))))
  val () = eqS ("Socket.recvVec/end-of-stream-again", "|",
                fn () => S.withStrm (fn (a, b) =>
                           (Socket.close a; vtext (Socket.recvVec (b, 10)) ^ "|" ^ vtext (Socket.recvVec (b, 10)))))
  (* "they raise Size if n < 0 or n > Word8Vector.maxLen"; the other end is
     closed, so that a receive that is made anyway does not wait *)
  val () = T.raises ("Socket.recvVec/negative", T.isSize,
                     fn () => S.withStrm (fn (a, b) => (Socket.close a; Socket.recvVec (b, ~1))))
  val () = T.raises ("Socket.recvVec/above-maxLen", T.isSize,
                     fn () => S.withStrm (fn (a, b) =>
                                (Socket.close a;
                                 if Word8Vector.maxLen < valOf Int.maxInt then Socket.recvVec (b, Word8Vector.maxLen + 1)
                                 else raise Size)))
  (* "These functions raise SysErr if the socket sock has been closed" *)
  val () = T.raises ("Socket.recvVec/closed", S.isSysErr, fn () => Socket.recvVec (S.closedTcp (), 10))

  (* "if peek is true, the data is received but not discarded from the
     connection" *)
  val () = eqS ("Socket.recvVec'/peek", "peek|peek",
                fn () => S.withTcp (fn (c, s) =>
                           (ignore (S.send (c, "peek"));
                            if S.readable s then vtext (Socket.recvVec' (s, 10, S.peek)) ^ "|" ^ S.recvAll (s, 4)
                            else "nothing")))
  val () = eqS ("Socket.recvVec'/no-flags", "plain", fn () => S.withStrm (fn (a, b) => (ignore (S.send (a, "plain")); vtext (Socket.recvVec' (b, 10, S.noIn)))))
  val () = eqS ("Socket.recvVec'/end-of-stream", "", fn () => S.withStrm (fn (a, b) => (Socket.close a; vtext (Socket.recvVec' (b, 10, S.noIn)))))
  val () = T.raises ("Socket.recvVec'/negative", T.isSize,
                     fn () => S.withStrm (fn (a, b) => (Socket.close a; Socket.recvVec' (b, ~1, S.noIn))))
  val () = T.raises ("Socket.recvVec'/closed", S.isSysErr, fn () => Socket.recvVec' (S.closedTcp (), 10, S.peek))

  (* "They return the number of bytes actually received. If the connection
     has been closed at the other end or the slice is empty, then 0 is
     returned." *)
  val () = eqS ("Socket.recvArr/count-and-place", "4 ..abcd.. ef",
                fn () => S.withTcp (fn (c, s) =>
                           (ignore (S.send (c, "abcdef"));
                            if S.readable s then
                              let val a = S.filled 8
                                  val n = Socket.recvArr (s, Word8ArraySlice.slice (a, 2, SOME 4))
                              in Int.toString n ^ " " ^ S.shown a ^ " " ^ S.recvAll (s, 2) end
                            else "nothing")))
  val () = eqS ("Socket.recvArr/empty-slice", "0 kept",
                fn () => S.withTcp (fn (c, s) =>
                           (ignore (S.send (c, "kept"));
                            if S.readable s then
                              Int.toString (Socket.recvArr (s, Word8ArraySlice.slice (S.filled 4, 1, SOME 0)))
                              ^ " " ^ S.recvAll (s, 4)
                            else "nothing")))
  val () = eqI ("Socket.recvArr/end-of-stream", 0,
                fn () => S.withStrm (fn (a, b) => (Socket.close a; Socket.recvArr (b, Word8ArraySlice.full (S.filled 4)))))
  val () = T.raises ("Socket.recvArr/closed", S.isSysErr, fn () => Socket.recvArr (S.closedTcp (), Word8ArraySlice.full (S.filled 4)))
  val () = eqS ("Socket.recvArr'/peek", "3 xyz. xyz",
                fn () => S.withStrm (fn (a, b) =>
                           (ignore (S.send (a, "xyz"));
                            let val arr = S.filled 4
                                val n = Socket.recvArr' (b, Word8ArraySlice.full arr, S.peek)
                            in Int.toString n ^ " " ^ S.shown arr ^ " " ^ S.recvAll (b, 3) end)))
  val () = eqI ("Socket.recvArr'/end-of-stream", 0,
                fn () => S.withStrm (fn (a, b) => (Socket.close a; Socket.recvArr' (b, Word8ArraySlice.full (S.filled 4), S.noIn))))
  val () = T.raises ("Socket.recvArr'/closed", S.isSysErr,
                     fn () => Socket.recvArr' (S.closedTcp (), Word8ArraySlice.full (S.filled 4), S.noIn))
  (*>> recv *)

  (*<< recv-nonblocking *)
  (* "when the operation can complete without blocking, then the result is
     wrapped in SOME and if the operation would have to wait for input, then
     NONE is returned instead" *)
  val () = eqOS ("Socket.recvVecNB/nothing-there", NONE,
                 fn () => S.withTcp (fn (c, _) => Option.map vtext (Socket.recvVecNB (c, 10))))
  val () = eqOS ("Socket.recvVecNB/data", SOME "data",
                 fn () => S.withTcp (fn (c, s) => (ignore (S.send (c, "data")); Option.map vtext (S.eventually (fn () => Socket.recvVecNB (s, 10))))))
  val () = eqOS ("Socket.recvVecNB/end-of-stream", SOME "",
                 fn () => S.withTcp (fn (c, s) =>
                            (Socket.close c; if S.readable s then Option.map vtext (Socket.recvVecNB (s, 10)) else NONE)))
  (* recvVec (sock, 0) gives the empty vector without waiting *)
  val () = eqOS ("Socket.recvVecNB/zero", SOME "", fn () => S.withTcp (fn (c, _) => Option.map vtext (Socket.recvVecNB (c, 0))))
  val () = T.raises ("Socket.recvVecNB/negative", T.isSize, fn () => S.withTcp (fn (c, _) => Socket.recvVecNB (c, ~1)))
  val () = T.raises ("Socket.recvVecNB/closed", S.isSysErr, fn () => Socket.recvVecNB (S.closedTcp (), 10))
  (* a receive after NONE gets what comes later *)
  val () = eqS ("Socket.recvVecNB/then-blocking", "later",
                fn () => S.withTcp (fn (c, s) =>
                           case Socket.recvVecNB (c, 10) of
                             NONE => (ignore (S.send (s, "later")); S.recvAll (c, 5))
                           | SOME _ => "not NONE"))
  val () = eqOS ("Socket.recvVecNB'/nothing-there", NONE,
                 fn () => S.withStrm (fn (_, b) => Option.map vtext (Socket.recvVecNB' (b, 10, S.peek))))
  val () = eqOS ("Socket.recvVecNB'/peek", SOME "seen|seen",
                 fn () => S.withStrm (fn (a, b) =>
                            (ignore (S.send (a, "seen"));
                             Option.map (fn v => vtext v ^ "|" ^ S.recvAll (b, 4)) (Socket.recvVecNB' (b, 10, S.peek)))))
  val () = T.raises ("Socket.recvVecNB'/negative", T.isSize, fn () => S.withStrm (fn (_, b) => Socket.recvVecNB' (b, ~1, S.noIn)))
  val () = T.raises ("Socket.recvVecNB'/closed", S.isSysErr, fn () => Socket.recvVecNB' (S.closedTcp (), 10, S.noIn))

  val () = eqOI ("Socket.recvArrNB/nothing-there", NONE,
                 fn () => S.withTcp (fn (c, _) => Socket.recvArrNB (c, Word8ArraySlice.full (S.filled 4))))
  val () = eqS ("Socket.recvArrNB/count-and-place", "3 .abc",
                fn () => S.withTcp (fn (c, s) =>
                           (ignore (S.send (c, "abc"));
                            let val a = S.filled 4
                            in
                              case S.eventually (fn () => Socket.recvArrNB (s, Word8ArraySlice.slice (a, 1, NONE))) of
                                SOME n => Int.toString n ^ " " ^ S.shown a
                              | NONE => "NONE"
                            end)))
  val () = eqOI ("Socket.recvArrNB/end-of-stream", SOME 0,
                 fn () => S.withStrm (fn (a, b) => (Socket.close a; Socket.recvArrNB (b, Word8ArraySlice.full (S.filled 4)))))
  val () = eqOI ("Socket.recvArrNB/empty-slice", SOME 0,
                 fn () => S.withStrm (fn (_, b) => Socket.recvArrNB (b, Word8ArraySlice.slice (S.filled 4, 4, NONE))))
  val () = T.raises ("Socket.recvArrNB/closed", S.isSysErr, fn () => Socket.recvArrNB (S.closedTcp (), Word8ArraySlice.full (S.filled 4)))
  val () = eqOI ("Socket.recvArrNB'/nothing-there", NONE,
                 fn () => S.withStrm (fn (_, b) => Socket.recvArrNB' (b, Word8ArraySlice.full (S.filled 4), S.noIn)))
  val () = eqS ("Socket.recvArrNB'/peek", "2 ok ok",
                fn () => S.withStrm (fn (a, b) =>
                           (ignore (S.send (a, "ok"));
                            let val arr = S.filled 2
                            in
                              case Socket.recvArrNB' (b, Word8ArraySlice.full arr, S.peek) of
                                SOME n => Int.toString n ^ " " ^ S.shown arr ^ " " ^ S.recvAll (b, 2)
                              | NONE => "NONE"
                            end)))
  val () = T.raises ("Socket.recvArrNB'/closed", S.isSysErr,
                     fn () => Socket.recvArrNB' (S.closedTcp (), Word8ArraySlice.full (S.filled 4), S.noIn))
  (*>> recv-nonblocking *)

  (*<< send-nonblocking *)
  (* "when the operation can complete without blocking, then the result is
     wrapped in SOME and if the operation would have to wait to send the data,
     then NONE is returned instead" *)
  val () = eqS ("Socket.sendVecNB/room", "SOME 5 fresh",
                fn () => S.withTcp (fn (c, s) =>
                           T.option T.int (Socket.sendVecNB (c, S.vslice "fresh")) ^ " " ^ S.recvAll (s, 5)))
  val () = eqS ("Socket.sendVecNB'/room", "SOME 3 new",
                fn () => S.withTcp (fn (c, s) =>
                           T.option T.int (Socket.sendVecNB' (c, S.vslice "new", S.noOut)) ^ " " ^ S.recvAll (s, 3)))
  val () = eqS ("Socket.sendArrNB/room", "SOME 2 ab",
                fn () => S.withStrm (fn (a, b) =>
                           T.option T.int (Socket.sendArrNB (a, asub ("xaby", 1, 2))) ^ " " ^ S.recvAll (b, 2)))
  val () = eqS ("Socket.sendArrNB'/room", "SOME 4 arr!",
                fn () => S.withStrm (fn (a, b) =>
                           T.option T.int (Socket.sendArrNB' (a, S.aslice "arr!", S.noOut)) ^ " " ^ S.recvAll (b, 4)))
  (* A peer that reads nothing: the buffers fill up, and then a send would
     have to wait. *)
  val chunk = Word8VectorSlice.full (Word8Vector.tabulate (65536, fn i => Word8.fromInt (i mod 256)))
  fun fillUp (c : S.tcp) : bool =
    let fun go k = k > 0 andalso (case Socket.sendVecNB (c, chunk) of NONE => true | SOME _ => go (k - 1))
    in go 4096 end
  fun whenFull (f : S.tcp -> 'a) : 'a option =
    S.withTcp (fn (c, s) =>
      (Socket.Ctl.setSNDBUF (c, 4096); Socket.Ctl.setRCVBUF (s, 4096);
       if fillUp c then SOME (f c) else NONE))
  val () = eqB ("Socket.sendVecNB/full", true,
                fn () => whenFull (fn a => Socket.sendVecNB (a, S.vslice "x")) = SOME NONE)
  val () = eqB ("Socket.sendVecNB'/full", true,
                fn () => whenFull (fn a => Socket.sendVecNB' (a, S.vslice "x", S.noOut)) = SOME NONE)
  val () = eqB ("Socket.sendArrNB/full", true,
                fn () => whenFull (fn a => Socket.sendArrNB (a, S.aslice "x")) = SOME NONE)
  val () = eqB ("Socket.sendArrNB'/full", true,
                fn () => whenFull (fn a => Socket.sendArrNB' (a, S.aslice "x", S.noOut)) = SOME NONE)
  val () = T.raises ("Socket.sendVecNB/closed", S.isSysErr, fn () => Socket.sendVecNB (S.closedTcp (), S.vslice "x"))
  val () = T.raises ("Socket.sendVecNB'/closed", S.isSysErr, fn () => Socket.sendVecNB' (S.closedTcp (), S.vslice "x", S.noOut))
  val () = T.raises ("Socket.sendArrNB/closed", S.isSysErr, fn () => Socket.sendArrNB (S.closedTcp (), S.aslice "x"))
  val () = T.raises ("Socket.sendArrNB'/closed", S.isSysErr, fn () => Socket.sendArrNB' (S.closedTcp (), S.aslice "x", S.noOut))
  (*>> send-nonblocking *)
end
