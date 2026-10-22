(* The SML side of bin/rune-protocol-check interop zmtp: a ROUTER that echoes each
   message reversed (and publishes when asked), a REP that answers
   "pong:" and the request, and a PUB; it writes their ports to the file
   its argument names, and ends when the ROUTER is told "quit" or after
   twenty seconds. *)
val portFile = case CommandLine.arguments () of [f] => f | _ => "zmtp-ports"
val router = Zmtp.bind (Zmtp.Router, {host = "127.0.0.1", port = 0})
val rep = Zmtp.bind (Zmtp.Rep, {host = "127.0.0.1", port = 0})
val pub = Zmtp.bind (Zmtp.Pub, {host = "127.0.0.1", port = 0})
val () =
  let val out = TextIO.openOut (portFile ^ ".new")
  in
    TextIO.output (out, String.concatWith " " (map (Int.toString o Zmtp.port) [router, rep, pub]) ^ "\n");
    TextIO.closeOut out;
    OS.FileSys.rename {old = portFile ^ ".new", new = portFile}
  end
val deadline = Time.+ (Time.now (), Time.fromSeconds 20)
fun serve () =
  if Time.> (Time.now (), deadline) then print "server: out of time\n"
  else
    (ignore (Zmtp.wait ([router, rep, pub], SOME (Time.fromMilliseconds 100)));
     case Zmtp.receive rep of
       SOME m => Zmtp.send (rep, map (fn x => "pong:" ^ x) m)
     | NONE => ();
     case Zmtp.receive router of
       SOME [id, "quit"] => (Zmtp.send (router, [id, "bye"]); Zmtp.flush (router, SOME (Time.fromSeconds 2)); print "server: done\n")
     | SOME [id, "publish"] => (Zmtp.send (pub, ["other", "no"]); Zmtp.send (pub, ["topic.x", "data"]);
                                 Zmtp.send (router, [id, "published"]); serve ())
     | SOME (id :: parts) => (Zmtp.send (router, id :: rev parts); serve ())
     | _ => serve ())
val () = serve ()
