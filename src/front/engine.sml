(* The REPL's engine as a child of a front in another process -- the Jupyter
   kernel (src/kernel/kernel.sml), the debug adapter (src/dap/adapter.sml) --
   started and spoken to (docs/repl-protocol.md, The channel). Where the
   system forks, the engine's channel is its descriptors 3 and 4, two pipes
   of the front's; where it does not (Windows, whose fork is a second VM,
   which takes no pipes), or where RUNE_ENGINE_CONNECT is set, it is a
   connection to a port of 127.0.0.1 the front listens on, whose first line
   is a token of 128 random bits, compared in constant time
   (`--engine-connect`). Either way the engine's output and error are pipes
   of the front's, and its input is nothing. The user's interrupt is SIGINT
   to it, or on Windows an event it watches (RUNE_INTERRUPT_EVENT). *)
structure EngineClient =
struct
  (* the engine: its process, its channel -- what writes a message's bytes,
     what reads some (none at the end), what polls for them --, its output
     and error, its interrupt, and what closes the channel *)
  type engine = {pid : Posix.ProcEnv.pid, write : string -> unit, read : unit -> string,
                 poll : OS.IO.poll_desc, out : Posix.IO.file_desc, errs : Posix.IO.file_desc,
                 interrupt : unit -> unit, close : unit -> unit}

  fun fd (k : int) = Posix.FileSys.wordToFD (Word.fromInt k)

  fun writeAll (f : Posix.IO.file_desc, s : string) : unit =
    let
      val bytes = Byte.stringToBytes s
      fun go i = if i >= Word8Vector.length bytes then ()
                 else go (i + Posix.IO.writeVec (f, Word8VectorSlice.slice (bytes, i, NONE)))
    in go 0 end

  fun pollOf (f : Posix.IO.file_desc) = Option.valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD f))

  (* a path as the process sees it from anywhere: as it is where it is
     absolute -- a drive's (C:\...) and a share's (\\host\...) too, which
     OS.Path does not take for absolute -- else from the directory *)
  fun absolute (p : string) : string =
    let
      val drive = size p >= 2 andalso Char.isAlpha (String.sub (p, 0)) andalso String.sub (p, 1) = #":"
    in
      if OS.Path.isAbsolute p orelse drive orelse String.isPrefix "\\\\" p then p
      else OS.Path.concat (OS.FileSys.getDir (), p)
    end

  fun onWindows () =
    List.exists (fn (k, v) => k = "sysname" andalso v = "Windows") (Posix.ProcEnv.uname ()) handle _ => false

  fun args (vm : string, image : string, channel : string list) =
    [vm, "--heap-size", "67108864", "--restore", image, "--", "--no-init"] @ channel

  (* its channel the descriptors 3 and 4, by fork; every other descriptor
     the child closed, so that it holds none of the front's *)
  fun byFork (vm : string, image : string, fail : string -> unit) : engine =
    let
      val {infd = toR, outfd = toW} = Posix.IO.pipe ()
      val {infd = fromR, outfd = fromW} = Posix.IO.pipe ()
      val {infd = outR, outfd = outW} = Posix.IO.pipe ()
      val {infd = errR, outfd = errW} = Posix.IO.pipe ()
    in
      case Posix.Process.fork () of
        NONE =>
          (Posix.IO.dup2 {old = toR, new = fd 3};
           Posix.IO.dup2 {old = fromW, new = fd 4};
           Posix.IO.dup2 {old = outW, new = fd 1};
           Posix.IO.dup2 {old = errW, new = fd 2};
           (let val null = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
            in Posix.IO.dup2 {old = null, new = fd 0} end handle OS.SysErr _ => ());
           let fun shut k = if k > 1023 then () else ((Posix.IO.close (fd k) handle OS.SysErr _ => ()); shut (k + 1))
           in shut 5 end;
           Posix.Process.exec (vm, args (vm, image, ["--engine"]))
           handle OS.SysErr (m, _) => (fail ("cannot start the engine " ^ vm ^ ": " ^ m); Posix.Process.exit 0w127))
      | SOME pid =>
          (List.app Posix.IO.close [toR, fromW, outW, errW];
           {pid = pid, write = fn s => writeAll (toW, s),
            read = fn () => Byte.bytesToString (Posix.IO.readVec (fromR, 65536)),
            poll = pollOf fromR, out = outR, errs = errR,
            interrupt = fn () => Posix.Process.kill (Posix.Process.K_PROC pid, Posix.Signal.int),
            close = fn () => (Posix.IO.close toW handle OS.SysErr _ => ())})
    end

  fun hex (s : string) : string =
    String.concat (List.map (fn c => StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c))) (String.explode s))

  (* the same bytes, every one compared whatever the others are *)
  fun sameSecret (a : string, b : string) : bool =
    size a = size b
    andalso CharVector.foldli (fn (i, c, acc) => Word.orb (acc, Word.xorb (Word.fromInt (Char.ord c),
                                                                         Word.fromInt (Char.ord (String.sub (b, i))))))
                              0w0 a = 0w0

  exception Refused of string

  (* its channel a connection to a port of 127.0.0.1, its first line the token *)
  fun byConnection (vm : string, image : string) : engine =
    let
      val secret = RuneRuntime.randomBytes 16
      val () = if size secret < 16 then raise Refused "the system gives no randomness for the engine's token" else ()
      val token = hex secret
      val listener = INetSock.TCP.socket ()
      val loopback = valOf (NetHostDB.fromString "127.0.0.1")
      val () = Socket.bind (listener, INetSock.toAddr (loopback, 0))
      val () = Socket.listen (listener, 1)
      val (_, port) = INetSock.fromAddr (Socket.Ctl.getSockName listener)
      val event = RuneRuntime.interruptEvent ()
      val {infd = outR, outfd = outW} = Posix.IO.pipe ()
      val {infd = errR, outfd = errW} = Posix.IO.pipe ()
      (* the engine's interrupt ours, not the notebook's (JPY_INTERRUPT_EVENT,
         whose handle it would not have) *)
      val env = List.filter (fn v => not (List.exists (fn n => String.isPrefix (n ^ "=") v)
                                                       ["RUNE_ENGINE_TOKEN", "RUNE_INTERRUPT_EVENT", "JPY_INTERRUPT_EVENT"]))
                            (Posix.ProcEnv.environ ())
                @ ["RUNE_ENGINE_TOKEN=" ^ token]
                @ (if event >= 0 then ["RUNE_INTERRUPT_EVENT=" ^ Int.toString event] else [])
      fun number f = SysWord.toInt (Posix.FileSys.fdToWord f)
      val pid = Posix.Process.wordToPid (SysWord.fromInt
                  (RuneRuntime.spawn (vm, args (vm, image, ["--engine-connect", Int.toString port]), SOME env,
                                      [~1, number outW, number errW])))
      val () = (Posix.IO.close outW; Posix.IO.close errW)
      (* the engine's connection, within half a minute *)
      val () =
        if List.null (OS.IO.poll ([OS.IO.pollIn (valOf (OS.IO.pollDesc (Socket.ioDesc listener)))], SOME (Time.fromSeconds 30)))
        then (Socket.close listener; raise Refused "the engine did not connect")
        else ()
      val (conn, _) = Socket.accept listener
      val () = Socket.close listener
      val pending = ref ""
      fun recv () = Byte.bytesToString (Socket.recvVec (conn, 65536))
      (* its first line, the token, at most 256 bytes *)
      fun firstLine () =
        case CharVector.findi (fn (_, c) => c = #"\n") (!pending) of
          SOME (i, _) =>
            let val l = String.substring (!pending, 0, i)
            in pending := String.extract (!pending, i + 1, NONE); l end
        | NONE =>
            if size (!pending) > 256 then raise Refused "no token"
            else case recv () of
                   "" => raise Refused "the engine closed its connection"
                 | b => (pending := !pending ^ b; firstLine ())
      val line = firstLine ()
      val line = if String.isSuffix "\r" line then String.substring (line, 0, size line - 1) else line
      val () = if sameSecret (line, token) then () else (Socket.close conn; raise Refused "the engine's token is not ours")
      fun send s =
        let
          val bytes = Byte.stringToBytes s
          fun go i = if i >= Word8Vector.length bytes then ()
                     else go (i + Socket.sendVec (conn, Word8VectorSlice.slice (bytes, i, NONE)))
        in go 0 end
    in
      {pid = pid, write = send,
       read = fn () => if !pending <> "" then (!pending before pending := "") else recv (),
       poll = valOf (OS.IO.pollDesc (Socket.ioDesc conn)), out = outR, errs = errR,
       interrupt = fn () =>
                     if event >= 0 then ignore (RuneRuntime.setInterrupt event)
                     else Posix.Process.kill (Posix.Process.K_PROC pid, Posix.Signal.int),
       close = fn () => (Socket.close conn handle OS.SysErr _ => ())}
    end

  (* the engine started, as the system allows *)
  fun start (vm : string, image : string, fail : string -> unit) : engine =
    if onWindows () orelse isSome (OS.Process.getEnv "RUNE_ENGINE_CONNECT") then byConnection (vm, image)
    else byFork (vm, image, fail)

  (* the engine ended -- told to (shutdown), or killed -- reaped, and then
     its channel closed: a connection closed first would fail the answer to
     the shutdown *)
  fun finish (e : engine) : unit =
    ((ignore (Posix.Process.waitpid (Posix.Process.W_CHILD (#pid e), []))) handle OS.SysErr _ => ();
     #close e ())
end
