(* requires: Socket INetSock UnixSock NetHostDB Byte OS *)
(* uses: fn/sockets.sml *)
(* Socket (signature SOCKET): sending and receiving datagrams, the blocking
   and the non-blocking forms, with and without flags. Expected values
   follow https://smlfamily.github.io/Basis/socket.html.

   The sockets are UDP sockets bound to the loopback interface, on ports the
   system picks, and Unix-domain datagram sockets with names in the current
   directory (fn/sockets.sml). A blocking receive is only called once the
   socket is readable (waiting for at most 5 s), so that nothing waits for
   ever. *)
structure TestSocketDgram =
struct
  structure S = Sockets
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqOS = T.eq (T.option T.string)
  val dontRoute = {don't_route = true, oob = false}
  fun addr s = Socket.Ctl.getSockName s
  fun vsub (s, i, n) = Word8VectorSlice.slice (S.bytes s, i, SOME n)
  fun asub (s, i, n) = Word8ArraySlice.slice (#1 (Word8ArraySlice.base (S.aslice s)), i, SOME n)

  (* the next message b received, once b is readable; the checks of
     recvVecFrom and recvArrFrom look at the address it came from *)
  fun received (b : S.udp) (n : int) : string =
    if S.readable b then
      case Socket.recvVecFromNB (b, n) of
        SOME (v, _) => S.text v
      | NONE => "NONE"
    else "nothing"
  fun from (a : S.udp) (sa : INetSock.sock_addr) : string =
    if Socket.sameAddr (sa, addr a) then " from a" else " from elsewhere"
  fun sendThen (make : S.udp * S.udp -> unit) (n : int) : string =
    S.withUdp (fn (a, b) => (make (a, b); received b n))

  (*<< send *)
  (* "send the message specified by the slice slice on the datagram socket
     sock to the address sa" *)
  val () = eqS ("Socket.sendVecTo/arrives", "one",
                fn () => sendThen (fn (a, b) => Socket.sendVecTo (a, addr b, S.vslice "one")) 100)
  val () = eqS ("Socket.sendVecTo/slice", "cde",
                fn () => sendThen (fn (a, b) => Socket.sendVecTo (a, addr b, vsub ("abcdefg", 2, 3))) 100)
  val () = eqS ("Socket.sendVecTo/empty-message", "",
                fn () => sendThen (fn (a, b) => Socket.sendVecTo (a, addr b, S.vslice "")) 100)
  (* "These functions raise SysErr if sock has been closed" *)
  val () = T.raises ("Socket.sendVecTo/closed", S.isSysErr,
                     fn () => Socket.sendVecTo (S.closedUdp (), INetSock.toAddr (S.loopback (), 9), S.vslice "x"))
  val () = eqS ("Socket.sendArrTo/arrives", "two",
                fn () => sendThen (fn (a, b) => Socket.sendArrTo (a, addr b, S.aslice "two")) 100)
  val () = eqS ("Socket.sendArrTo/slice", "bc",
                fn () => sendThen (fn (a, b) => Socket.sendArrTo (a, addr b, asub ("abcd", 1, 2))) 100)
  val () = T.raises ("Socket.sendArrTo/closed", S.isSysErr,
                     fn () => Socket.sendArrTo (S.closedUdp (), INetSock.toAddr (S.loopback (), 9), S.aslice "x"))
  val () = eqS ("Socket.sendVecTo'/no-flags", "three",
                fn () => sendThen (fn (a, b) => Socket.sendVecTo' (a, addr b, S.vslice "three", S.noOut)) 100)
  (* "If the don't_route flag is true, the data is sent bypassing the normal
     routing mechanism of the protocol": the loopback interface is at hand *)
  val () = eqS ("Socket.sendVecTo'/don't_route", "local",
                fn () => sendThen (fn (a, b) => Socket.sendVecTo' (a, addr b, S.vslice "local", dontRoute)) 100)
  val () = T.raises ("Socket.sendVecTo'/closed", S.isSysErr,
                     fn () => Socket.sendVecTo' (S.closedUdp (), INetSock.toAddr (S.loopback (), 9), S.vslice "x", S.noOut))
  val () = eqS ("Socket.sendArrTo'/no-flags", "four",
                fn () => sendThen (fn (a, b) => Socket.sendArrTo' (a, addr b, S.aslice "four", S.noOut)) 100)
  val () = eqS ("Socket.sendArrTo'/don't_route", "local",
                fn () => sendThen (fn (a, b) => Socket.sendArrTo' (a, addr b, S.aslice "local", dontRoute)) 100)
  val () = T.raises ("Socket.sendArrTo'/closed", S.isSysErr,
                     fn () => Socket.sendArrTo' (S.closedUdp (), INetSock.toAddr (S.loopback (), 9), S.aslice "x", S.noOut))
  (*>> send *)

  (*<< recv *)
  (* "return a pair (vec,sa), where the vector vec is the received message,
     and sa is the socket address from the which the data originated" *)
  fun recvFrom (a : S.udp, b : S.udp) (n : int) : string =
    if S.readable b then let val (v, sa) = Socket.recvVecFrom (b, n) in S.text v ^ from a sa end
    else "nothing"
  val () = eqS ("Socket.recvVecFrom/message-and-address", "hello from a",
                fn () => S.withUdp (fn (a, b) => (Socket.sendVecTo (a, addr b, S.vslice "hello"); recvFrom (a, b) 100)))
  val () = eqS ("Socket.recvVecFrom/one-message-at-a-time", "ab from a|cde from a",
                fn () => S.withUdp (fn (a, b) =>
                           (Socket.sendVecTo (a, addr b, S.vslice "ab"); Socket.sendVecTo (a, addr b, S.vslice "cde");
                            recvFrom (a, b) 100 ^ "|" ^ recvFrom (a, b) 100)))
  (* "receive up to n bytes ... If the message is larger than n, then data
     may be lost." *)
  val () = eqS ("Socket.recvVecFrom/at-most-n", "abc from a",
                fn () => S.withUdp (fn (a, b) => (Socket.sendVecTo (a, addr b, S.vslice "abcdefgh"); recvFrom (a, b) 3)))
  val () = eqS ("Socket.recvVecFrom/unix", "unix from sender.sock",
                fn () => S.withPath "dgram-receiver.sock" (fn rpath =>
                           S.withPath "dgram-sender.sock" (fn spath =>
                             S.withSocket UnixSock.DGrm.socket (fn r =>
                               S.withSocket UnixSock.DGrm.socket (fn s =>
                                 (Socket.bind (r, UnixSock.toAddr rpath); Socket.bind (s, UnixSock.toAddr spath);
                                  Socket.sendVecTo (s, UnixSock.toAddr rpath, S.vslice "unix");
                                  let val (v, sa) = Socket.recvVecFrom (r, 100)
                                  in S.text v ^ " from " ^ (if UnixSock.fromAddr sa = spath then "sender.sock" else UnixSock.fromAddr sa) end))))))
  (* "they raise Size if n < 0 or n > Word8Vector.maxLen"; a message is
     waiting, so that a receive that is made anyway does not wait *)
  fun withMessage (f : S.udp -> 'a) : 'a =
    S.withUdp (fn (a, b) => (Socket.sendVecTo (a, addr b, S.vslice "m"); if S.readable b then f b else raise Fail "no message"))
  val () = T.raises ("Socket.recvVecFrom/negative", T.isSize, fn () => withMessage (fn b => Socket.recvVecFrom (b, ~1)))
  val () = T.raises ("Socket.recvVecFrom/above-maxLen", T.isSize,
                     fn () => withMessage (fn b =>
                                if Word8Vector.maxLen < valOf Int.maxInt then Socket.recvVecFrom (b, Word8Vector.maxLen + 1)
                                else raise Size))
  (* "These functions raise SysErr if sock has been closed" *)
  val () = T.raises ("Socket.recvVecFrom/closed", S.isSysErr, fn () => Socket.recvVecFrom (S.closedUdp (), 10))

  (* "if peek is true, the data is received but not discarded from the
     connection" *)
  val () = eqS ("Socket.recvVecFrom'/peek", "peek from a|peek",
                fn () => S.withUdp (fn (a, b) =>
                           (Socket.sendVecTo (a, addr b, S.vslice "peek");
                            if S.readable b then
                              let val (v, sa) = Socket.recvVecFrom' (b, 100, S.peek) in S.text v ^ from a sa ^ "|" ^ received b 100 end
                            else "nothing")))
  val () = eqS ("Socket.recvVecFrom'/no-flags", "plain",
                fn () => S.withUdp (fn (a, b) =>
                           (Socket.sendVecTo (a, addr b, S.vslice "plain");
                            if S.readable b then S.text (#1 (Socket.recvVecFrom' (b, 100, S.noIn))) else "nothing")))
  val () = T.raises ("Socket.recvVecFrom'/negative", T.isSize, fn () => withMessage (fn b => Socket.recvVecFrom' (b, ~1, S.noIn)))
  val () = T.raises ("Socket.recvVecFrom'/closed", S.isSysErr, fn () => Socket.recvVecFrom' (S.closedUdp (), 10, S.noIn))

  (* "They return the number of bytes actually received." *)
  fun intoSlice (recv : S.udp * Word8ArraySlice.slice -> int * INetSock.sock_addr) (message, start, len) =
    S.withUdp (fn (a, b) =>
      (Socket.sendVecTo (a, addr b, S.vslice message);
       if S.readable b then
         let
           val arr = S.filled 8
           val (n, sa) = recv (b, Word8ArraySlice.slice (arr, start, SOME len))
         in Int.toString n ^ " " ^ S.shown arr ^ from a sa end
       else "nothing"))
  val () = eqS ("Socket.recvArrFrom/count-place-and-address", "4 ..wxyz.. from a",
                fn () => intoSlice Socket.recvArrFrom ("wxyz", 2, 4))
  val () = eqS ("Socket.recvArrFrom/at-most-the-slice", "2 ab...... from a",
                fn () => intoSlice Socket.recvArrFrom ("abcd", 0, 2))
  (* "If ... the slice is empty, then 0 is returned." *)
  val () = eqS ("Socket.recvArrFrom/empty-slice", "0 ........ from a",
                fn () => intoSlice Socket.recvArrFrom ("abcd", 3, 0))
  val () = T.raises ("Socket.recvArrFrom/closed", S.isSysErr,
                     fn () => Socket.recvArrFrom (S.closedUdp (), Word8ArraySlice.full (S.filled 4)))
  val () = eqS ("Socket.recvArrFrom'/no-flags", "3 .abc.... from a",
                fn () => intoSlice (fn (b, sl) => Socket.recvArrFrom' (b, sl, S.noIn)) ("abc", 1, 5))
  val () = eqS ("Socket.recvArrFrom'/peek", "2 ok......|ok",
                fn () => S.withUdp (fn (a, b) =>
                           (Socket.sendVecTo (a, addr b, S.vslice "ok");
                            if S.readable b then
                              let
                                val arr = S.filled 8
                                val (n, _) = Socket.recvArrFrom' (b, Word8ArraySlice.full arr, S.peek)
                              in Int.toString n ^ " " ^ S.shown arr ^ "|" ^ received b 100 end
                            else "nothing")))
  val () = T.raises ("Socket.recvArrFrom'/closed", S.isSysErr,
                     fn () => Socket.recvArrFrom' (S.closedUdp (), Word8ArraySlice.full (S.filled 4), S.noIn))
  (*>> recv *)

  (*<< recv-nonblocking *)
  (* "when the operation can complete without blocking, then the result is
     wrapped in SOME and if the operation would have to wait for input, then
     NONE is returned instead" *)
  fun nb (a : S.udp) (got : (Word8Vector.vector * INetSock.sock_addr) option) : string option =
    Option.map (fn (v, sa) => S.text v ^ from a sa) got
  val () = eqOS ("Socket.recvVecFromNB/nothing-there", NONE,
                 fn () => S.withUdp (fn (a, b) => nb a (Socket.recvVecFromNB (b, 100))))
  val () = eqOS ("Socket.recvVecFromNB/message", SOME "nb from a",
                 fn () => S.withUdp (fn (a, b) =>
                            (Socket.sendVecTo (a, addr b, S.vslice "nb");
                             nb a (S.eventually (fn () => Socket.recvVecFromNB (b, 100))))))
  val () = T.raises ("Socket.recvVecFromNB/negative", T.isSize, fn () => S.withUdp (fn (_, b) => Socket.recvVecFromNB (b, ~1)))
  val () = T.raises ("Socket.recvVecFromNB/closed", S.isSysErr, fn () => Socket.recvVecFromNB (S.closedUdp (), 10))
  val () = eqOS ("Socket.recvVecFromNB'/nothing-there", NONE,
                 fn () => S.withUdp (fn (a, b) => nb a (Socket.recvVecFromNB' (b, 100, S.peek))))
  val () = eqOS ("Socket.recvVecFromNB'/peek", SOME "seen from a|seen",
                 fn () => S.withUdp (fn (a, b) =>
                            (Socket.sendVecTo (a, addr b, S.vslice "seen");
                             Option.map (fn first => first ^ "|" ^ received b 100)
                                        (nb a (S.eventually (fn () => Socket.recvVecFromNB' (b, 100, S.peek)))))))
  val () = T.raises ("Socket.recvVecFromNB'/negative", T.isSize, fn () => S.withUdp (fn (_, b) => Socket.recvVecFromNB' (b, ~1, S.noIn)))
  val () = T.raises ("Socket.recvVecFromNB'/closed", S.isSysErr, fn () => Socket.recvVecFromNB' (S.closedUdp (), 10, S.noIn))

  fun nbArr (recv : S.udp * Word8ArraySlice.slice -> (int * INetSock.sock_addr) option) (send : bool) =
    S.withUdp (fn (a, b) =>
      let
        val arr = S.filled 4
        val () = if send then Socket.sendVecTo (a, addr b, S.vslice "xy") else ()
        val got = if send then S.eventually (fn () => recv (b, Word8ArraySlice.slice (arr, 1, NONE)))
                  else recv (b, Word8ArraySlice.slice (arr, 1, NONE))
      in
        case got of
          SOME (n, sa) => "SOME " ^ Int.toString n ^ " " ^ S.shown arr ^ from a sa
        | NONE => "NONE"
      end)
  val () = eqS ("Socket.recvArrFromNB/nothing-there", "NONE", fn () => nbArr Socket.recvArrFromNB false)
  val () = eqS ("Socket.recvArrFromNB/message", "SOME 2 .xy. from a", fn () => nbArr Socket.recvArrFromNB true)
  val () = T.raises ("Socket.recvArrFromNB/closed", S.isSysErr,
                     fn () => Socket.recvArrFromNB (S.closedUdp (), Word8ArraySlice.full (S.filled 4)))
  val () = eqS ("Socket.recvArrFromNB'/nothing-there", "NONE",
                fn () => nbArr (fn (b, sl) => Socket.recvArrFromNB' (b, sl, S.noIn)) false)
  val () = eqS ("Socket.recvArrFromNB'/message", "SOME 2 .xy. from a",
                fn () => nbArr (fn (b, sl) => Socket.recvArrFromNB' (b, sl, S.noIn)) true)
  val () = eqS ("Socket.recvArrFromNB'/peek", "SOME 2 .xy. from a|xy",
                fn () => S.withUdp (fn (a, b) =>
                           (Socket.sendVecTo (a, addr b, S.vslice "xy");
                            let val arr = S.filled 4
                            in
                              case S.eventually (fn () => Socket.recvArrFromNB' (b, Word8ArraySlice.slice (arr, 1, NONE), S.peek)) of
                                SOME (n, sa) => "SOME " ^ Int.toString n ^ " " ^ S.shown arr ^ from a sa ^ "|" ^ received b 100
                              | NONE => "NONE"
                            end)))
  val () = T.raises ("Socket.recvArrFromNB'/closed", S.isSysErr,
                     fn () => Socket.recvArrFromNB' (S.closedUdp (), Word8ArraySlice.full (S.filled 4), S.noIn))
  (*>> recv-nonblocking *)

  (*<< send-nonblocking *)
  (* "if the operation can complete without blocking, then the operation is
     performed and true is returned. Otherwise, false is returned and the
     message is not sent." *)
  fun sentNB (send : S.udp * INetSock.sock_addr -> bool) : string =
    S.withUdp (fn (a, b) => Bool.toString (send (a, addr b)) ^ " " ^ received b 100)
  val () = eqS ("Socket.sendVecToNB/room", "true nb1", fn () => sentNB (fn (a, to) => Socket.sendVecToNB (a, to, S.vslice "nb1")))
  val () = eqS ("Socket.sendArrToNB/room", "true nb2", fn () => sentNB (fn (a, to) => Socket.sendArrToNB (a, to, S.aslice "nb2")))
  val () = eqS ("Socket.sendVecToNB'/room", "true nb3",
                fn () => sentNB (fn (a, to) => Socket.sendVecToNB' (a, to, S.vslice "nb3", S.noOut)))
  val () = eqS ("Socket.sendArrToNB'/room", "true nb4",
                fn () => sentNB (fn (a, to) => Socket.sendArrToNB' (a, to, S.aslice "nb4", S.noOut)))
  val () = T.raises ("Socket.sendVecToNB/closed", S.isSysErr,
                     fn () => Socket.sendVecToNB (S.closedUdp (), INetSock.toAddr (S.loopback (), 9), S.vslice "x"))
  val () = T.raises ("Socket.sendArrToNB/closed", S.isSysErr,
                     fn () => Socket.sendArrToNB (S.closedUdp (), INetSock.toAddr (S.loopback (), 9), S.aslice "x"))
  val () = T.raises ("Socket.sendVecToNB'/closed", S.isSysErr,
                     fn () => Socket.sendVecToNB' (S.closedUdp (), INetSock.toAddr (S.loopback (), 9), S.vslice "x", S.noOut))
  val () = T.raises ("Socket.sendArrToNB'/closed", S.isSysErr,
                     fn () => Socket.sendArrToNB' (S.closedUdp (), INetSock.toAddr (S.loopback (), 9), S.aslice "x", S.noOut))

  (* A Unix-domain receiver that reads nothing: its queue fills up, and then
     a send would have to wait. *)
  val message = Word8VectorSlice.full (Word8Vector.tabulate (512, fn i => Word8.fromInt (i mod 256)))
  fun whenFull (f : S.dgrm * UnixSock.sock_addr -> bool) : bool option =
    S.withPath "dgram-full.sock" (fn path =>
      S.withSocket UnixSock.DGrm.socket (fn r =>
        S.withSocket UnixSock.DGrm.socket (fn s =>
          let
            val to = UnixSock.toAddr path
            fun fill k = k > 0 andalso (not (Socket.sendVecToNB (s, to, message)) orelse fill (k - 1))
          in
            Socket.bind (r, to);
            if fill 100000 then SOME (f (s, to)) else NONE
          end)))
  val () = T.eq (T.option T.bool) ("Socket.sendVecToNB/full", SOME false,
                                   fn () => whenFull (fn (s, to) => Socket.sendVecToNB (s, to, S.vslice "x")))
  val () = T.eq (T.option T.bool) ("Socket.sendArrToNB/full", SOME false,
                                   fn () => whenFull (fn (s, to) => Socket.sendArrToNB (s, to, S.aslice "x")))
  val () = T.eq (T.option T.bool) ("Socket.sendVecToNB'/full", SOME false,
                                   fn () => whenFull (fn (s, to) => Socket.sendVecToNB' (s, to, S.vslice "x", S.noOut)))
  val () = T.eq (T.option T.bool) ("Socket.sendArrToNB'/full", SOME false,
                                   fn () => whenFull (fn (s, to) => Socket.sendArrToNB' (s, to, S.aslice "x", S.noOut)))
  (*>> send-nonblocking *)
end
