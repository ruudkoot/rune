(* fork by a second VM (vm/image.c): what runevm --emulate-fork does here,
   and what fork is on Windows. The child has to carry on with all of the
   parent's state: a heap with a cycle in it, exceptions told apart by
   identity, a handler pushed before the fork, files half read and half
   written, the working directory, a pipe and a socket, close-on-exec, a
   directory stream, the rounding mode, the arguments, and it forks in turn.
   Each child prints and ends before its parent goes on, so the output has
   one order. *)
structure P = Posix.Process
structure FS = Posix.FileSys

fun status pid =
  case P.waitpid (P.W_CHILD pid, []) of
    (_, P.W_EXITED) => "0"
  | (_, P.W_EXITSTATUS w) => Word8.toString w
  | (_, P.W_SIGNALED _) => "signalled"
  | _ => "stopped"

(* Posix.Process.exit flushes nothing *)
fun exit w = (TextIO.flushOut TextIO.stdOut; P.exit w)

(* f runs in a child, which exits with what f returns *)
fun child name f =
  case P.fork () of
    NONE => exit (f () handle e => (print ("the child raised " ^ exnName e ^ "\n"); 0w99))
  | SOME pid => print (name ^ ": the child exited " ^ status pid ^ "\n")

fun say what b = print (what ^ ": " ^ Bool.toString b ^ "\n")

fun sort ([] : string list) = []
  | sort (x :: xs) =
      let fun insert (y, []) = [y]
            | insert (y, z :: zs) = if y <= z then y :: z :: zs else z :: insert (y, zs)
      in insert (x, sort xs) end

(* the heap: a ring of 1000 nodes, the last one's reference being tail *)
datatype node = End | Node of int * node ref
val tail = ref End
val ring = List.foldl (fn (k, next) => Node (k, ref next)) (Node (0, tail)) (List.tabulate (999, fn i => i + 1))
val () = tail := ring
fun laps n =
  let fun go (Node (k, r), steps, sum) = if steps = n * 1000 then (sum, r) else go (!r, steps + 1, sum + k)
        | go (End, _, sum) = (sum, tail)
  in go (ring, 0, 0) end
val () = child "a ring in the heap" (fn () =>
  let val (sum, _) = laps 2
      fun last (Node (0, r)) = r | last (Node (_, r)) = last (!r) | last End = ref End
  in
    print ("two laps: " ^ Int.toString sum ^ "\n");
    say "the last node's reference is the global one" (last ring = tail);
    tail := End;
    0w1
  end)
val () = say "the parent's ring is whole" (#1 (laps 1) = 499500)

(* exceptions *)
exception Mine of int
val mine = Mine 7
fun generative () = let exception Local in (Local, fn Local => true | _ => false) end
val (local1, isLocal1) = generative ()
val (local2, _) = generative ()
val () = child "exceptions" (fn () =>
  (say "Mine is Mine" ((raise mine) handle Mine 7 => true | _ => false);
   say "a generative exception is itself" (isLocal1 local1);
   say "and not another made by the same code" (not (isLocal1 local2));
   say "Div" ((1 div 0 = 0) handle Div => true | _ => false);
   say "Option" ((valOf NONE = 0) handle Option => true | _ => false);
   0w2))

(* a handler pushed before the fork *)
exception Back of string
val () =
  (case P.fork () of
     NONE => raise Back "the child"
   | SOME pid => print ("a handler pushed before the fork: the child exited " ^ status pid ^ "\n"))
  handle Back s => (print ("raised to in " ^ s ^ "\n"); exit 0w3)

(* the working directory and files *)
val home = OS.FileSys.getDir ()
val scratch = OS.FileSys.tmpName ()
val () = OS.FileSys.remove scratch handle OS.SysErr _ => ()
val () = OS.FileSys.mkDir scratch
val () = OS.FileSys.chDir scratch
val here = OS.FileSys.getDir ()
fun line k = "line " ^ StringCvt.padLeft #"0" 5 (Int.toString k) ^ "\n"
val () =
  let val out = TextIO.openOut "lines"
  in List.app (fn k => TextIO.output (out, line k)) (List.tabulate (20000, fn k => k)); TextIO.closeOut out end
val lines = TextIO.openIn "lines"
val () = List.app (fn _ => ignore (TextIO.inputLine lines)) [1, 2, 3]
val () = child "a file half read" (fn () =>
  let fun count n = case TextIO.inputLine lines of NONE => n | SOME _ => count (n + 1)
      val first = TextIO.inputLine lines
  in
    say "the working directory" (OS.FileSys.getDir () = here);
    print ("the child reads on at " ^ valOf first);
    print ("and then " ^ Int.toString (count 0) ^ " more\n");
    0w4
  end)
val () = TextIO.closeIn lines

val written = TextIO.openOut "written"
val () = TextIO.output (written, "the parent, before\n")
val () = TextIO.flushOut written
val () = child "a file half written" (fn () => (TextIO.output (written, "the child\n"); TextIO.closeOut written; 0w5))
val () = TextIO.output (written, "the parent, after\n")
val () = TextIO.closeOut written
val () = print (TextIO.inputAll (TextIO.openIn "written"))

(* descriptors *)
val {infd, outfd} = Posix.IO.pipe ()
val () = Posix.IO.setfd (infd, Posix.IO.FD.cloexec)
val () = child "a pipe" (fn () =>
  (say "close-on-exec kept" (Posix.IO.FD.anySet (Posix.IO.getfd infd, Posix.IO.FD.cloexec));
   say "and not given" (not (Posix.IO.FD.anySet (Posix.IO.getfd outfd, Posix.IO.FD.cloexec)));
   ignore (Posix.IO.writeVec (outfd, Word8VectorSlice.full (Byte.stringToBytes "through the pipe\n")));
   0w6))
val () = print (Byte.bytesToString (Posix.IO.readVec (infd, 100)))
val () = (Posix.IO.close infd; Posix.IO.close outfd)

val (s1, s2) : Socket.active UnixSock.stream_sock * Socket.active UnixSock.stream_sock = UnixSock.Strm.socketPair ()
val () = child "a socket" (fn () =>
  (ignore (Socket.sendVec (s1, Word8VectorSlice.full (Byte.stringToBytes "through a socket\n"))); 0w7))
val () = print (Byte.bytesToString (Socket.recvVec (s2, 100)))
val () = (Socket.close s1; Socket.close s2)

(* a directory stream *)
val () = OS.FileSys.mkDir "d"
val () = List.app (fn n => TextIO.closeOut (TextIO.openOut ("d/" ^ n))) ["a", "b", "c"]
val dir = FS.opendir "d"
val first = valOf (FS.readdir dir)
val () = child "a directory half read" (fn () =>
  let fun rest acc = case FS.readdir dir of NONE => acc | SOME n => rest (n :: acc)
      val names = rest []
  in
    print ("the child reads " ^ Int.toString (length names) ^ " more: " ^ String.concatWith " " (sort (first :: names)) ^ "\n");
    0w8
  end)
val () = FS.closedir dir

(* the rounding mode, the arguments, the process *)
val () = IEEEReal.setRoundingMode IEEEReal.TO_POSINF
val parent = Posix.ProcEnv.getpid ()
val name = CommandLine.name ()
val () = child "the rest" (fn () =>
  (say "the rounding mode" (IEEEReal.getRoundingMode () = IEEEReal.TO_POSINF);
   print ("the arguments: " ^ String.concatWith " " (CommandLine.arguments ()) ^ "\n");
   say "the name" (CommandLine.name () = name);
   say "the parent" (Posix.ProcEnv.getppid () = parent);
   say "a process of its own" (Posix.ProcEnv.getpid () <> parent);
   0w9))
val () = IEEEReal.setRoundingMode IEEEReal.TO_NEAREST

(* the child collects, and forks in turn *)
val () = child "a fork of the child" (fn () =>
  let val sum = List.foldl op+ 0 (List.tabulate (200000, fn k => k mod 7))
  in
    print ("the child allocates: " ^ Int.toString sum ^ "\n");
    child "the grandchild" (fn () => (print "the grandchild runs\n"; 0w11));
    0w10
  end)

val () = OS.FileSys.chDir home
val () = List.app (fn n => OS.FileSys.remove (scratch ^ "/" ^ n)) ["lines", "written", "d/a", "d/b", "d/c"]
val () = (OS.FileSys.rmDir (scratch ^ "/d"); OS.FileSys.rmDir scratch)
val () = print "done\n"
