(* Sockets for the tests of Socket, INetSock, UnixSock and GenericSock
   (socket*.sml, inetsock*.sml): connected pairs on the loopback interface
   and in the Unix domain, closed sockets, and waiting with a time limit, so
   that a check that goes wrong fails instead of waiting for ever. Nothing
   here opens a socket when the file is loaded.

   A closed socket is made just before the call that needs it: once closed,
   its descriptor number is free, and the next socket opened would get it.

   Poly/ML leaves the sockets that accept gives in blocking mode, where its
   ...NB functions wait: a check that expects NONE from a TCP pair uses the
   client (the first of withTcp), which socket made. *)
structure Sockets =
struct
  type tcp = Socket.active INetSock.stream_sock
  type tcpListener = Socket.passive INetSock.stream_sock
  type udp = INetSock.dgram_sock
  type strm = Socket.active UnixSock.stream_sock
  type dgrm = UnixSock.dgram_sock

  fun bytes (s : string) : Word8Vector.vector = Byte.stringToBytes s
  fun text (v : Word8Vector.vector) : string = Byte.bytesToString v
  fun vslice (s : string) : Word8VectorSlice.slice = Word8VectorSlice.full (bytes s)
  fun aslice (s : string) : Word8ArraySlice.slice =
    Word8ArraySlice.full (Word8Array.tabulate (size s, fn i => Byte.charToByte (String.sub (s, i))))

  (* an array of n bytes 0wxFF, and its contents as text with "." for 0wxFF
     (written Word8.fromInt 255: a host that compiles lib/basis, xc1, cannot
     type a word constant at the Word8 of lib/basis) *)
  fun filled n = Word8Array.array (n, Word8.fromInt 255)
  fun shown (a : Word8Array.array) : string =
    String.implode (List.tabulate (Word8Array.length a,
                                   fn i => let val b = Word8Array.sub (a, i)
                                           in if b = Word8.fromInt 255 then #"." else Byte.byteToChar b end))

  val isSysErr = fn OS.SysErr _ => true | _ => false
  val noOut = {don't_route = false, oob = false}
  val noIn = {peek = false, oob = false}
  val peek = {peek = true, oob = false}

  fun loopback () : NetHostDB.in_addr = valOf (NetHostDB.fromString "127.0.0.1")

  (* quietly f x: f x, whatever it raises (closing a socket that may be closed) *)
  fun quietly (f : 'a -> unit) (x : 'a) : unit = f x handle _ => ()
  fun closeAll (socks : ('af, 'st) Socket.sock list) = List.app (quietly Socket.close) socks

  (* using (acquire, release) f: f on what acquire gives, released after *)
  fun using (acquire : unit -> 'a, release : 'a -> unit) (f : 'a -> 'b) : 'b =
    let val x = acquire ()
    in (f x before release x) handle e => (release x; raise e) end

  fun portOf (s : 'st INetSock.sock) : int = #2 (INetSock.fromAddr (Socket.Ctl.getSockName s))
  fun hostOf (a : INetSock.sock_addr) : string = NetHostDB.toString (#1 (INetSock.fromAddr a))

  (* waiting for at most 5 seconds *)
  val patience = Time.fromReal 5.0
  fun readable (s : ('af, 'st) Socket.sock) : bool =
    not (null (#rds (Socket.select {rds = [Socket.sockDesc s], wrs = [], exs = [], timeout = SOME patience})))
  fun writable (s : ('af, 'st) Socket.sock) : bool =
    not (null (#wrs (Socket.select {rds = [], wrs = [Socket.sockDesc s], exs = [], timeout = SOME patience})))
  (* eventually f: f () until it gives SOME, every 10 ms for about 5 seconds *)
  fun eventually (f : unit -> 'a option) : 'a option =
    let
      fun go n =
        case f () of
          SOME x => SOME x
        | NONE => if n = 0 then NONE else (OS.Process.sleep (Time.fromReal 0.01); go (n - 1))
    in go 500 end

  (* TCP on the loopback interface, on a port the system picks *)
  fun tcpListener () : tcpListener =
    let val l = INetSock.TCP.socket ()
    in
      (Socket.bind (l, INetSock.toAddr (loopback (), 0)); Socket.listen (l, 8); l)
      handle e => (quietly Socket.close l; raise e)
    end
  (* a connected pair: the client, and the socket the listener accepted *)
  fun tcpPair () : tcp * tcp =
    let
      val l = tcpListener ()
      val c : tcp = INetSock.TCP.socket ()
    in
      (Socket.connect (c, Socket.Ctl.getSockName l);
       let val (s, _) = Socket.accept l in Socket.close l; (c, s) end)
      handle e => (quietly Socket.close l; quietly Socket.close c; raise e)
    end
  fun withTcp (f : tcp * tcp -> 'b) : 'b = using (tcpPair, fn (a, b) => closeAll [a, b]) f
  fun withListener (f : tcpListener -> 'b) : 'b = using (tcpListener, quietly Socket.close) f
  fun withSocket (make : unit -> ('af, 'st) Socket.sock) (f : ('af, 'st) Socket.sock -> 'b) : 'b =
    using (make, quietly Socket.close) f

  fun closedTcp () : tcp = let val s = INetSock.TCP.socket () in Socket.close s; s end
  fun closedListener () : tcpListener = let val s = INetSock.TCP.socket () in Socket.close s; s end
  fun closedUdp () : udp = let val s = INetSock.UDP.socket () in Socket.close s; s end

  (* UDP on the loopback interface *)
  fun udpBound () : udp =
    let val s = INetSock.UDP.socket ()
    in (Socket.bind (s, INetSock.toAddr (loopback (), 0)); s) handle e => (quietly Socket.close s; raise e) end
  fun udpPair () : udp * udp =
    let val a = udpBound ()
    in (a, udpBound ()) handle e => (quietly Socket.close a; raise e) end
  fun withUdp (f : udp * udp -> 'b) : 'b = using (udpPair, fn (a, b) => closeAll [a, b]) f

  (* The Unix domain: pairs, and names in the current directory, removed
     before and after. *)
  fun strmPair () : strm * strm = UnixSock.Strm.socketPair ()
  fun withStrm (f : strm * strm -> 'b) : 'b = using (strmPair, fn (a, b) => closeAll [a, b]) f
  fun dgrmPair () : dgrm * dgrm = UnixSock.DGrm.socketPair ()
  fun withDgrm (f : dgrm * dgrm -> 'b) : 'b = using (dgrmPair, fn (a, b) => closeAll [a, b]) f
  fun removeQuietly (path : string) = OS.FileSys.remove path handle _ => ()
  fun withPath (path : string) (f : string -> 'b) : 'b =
    using (fn () => (removeQuietly path; path), removeQuietly) f

  fun send (s : ('af, Socket.active Socket.stream) Socket.sock, str : string) : int = Socket.sendVec (s, vslice str)
  (* recvAll (s, n): n bytes, or fewer at the end of the stream or when no
     more come for 5 seconds *)
  fun recvAll (s : ('af, Socket.active Socket.stream) Socket.sock, n : int) : string =
    let
      fun go (acc, k) =
        if k >= n orelse not (readable s) then String.concat (rev acc)
        else
          case text (Socket.recvVec (s, n - k)) of
            "" => String.concat (rev acc)
          | got => go (got :: acc, k + size got)
    in go ([], 0) end
end
