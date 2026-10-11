(* Zmtp: the greeting and frames as ZMTP 3.1 writes them, read back in
   every split; then the kinds of socket talking to each other over the
   loopback interface in one process. tests/lib/zmtp/interop.sh talks to
   a peer written from the specification in Python. *)
structure ZmtpTest =
struct
  val failures = ref 0
  fun check (name, ok) = if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))

  open ZmtpWire

  fun wire () =
    let
      val g = greeting {mechanism = "NULL", server = false}
      val frames = [Data {more = true, body = ""}, Data {more = false, body = CharVector.tabulate (300, fn i => Char.chr (i mod 256))},
                    Command {name = "PING", data = "\000\010ctx"}, ready [("Socket-Type", "ROUTER"), ("Identity", "")]]
      val bytes = String.concat (map encode frames)
      fun all parts = #1 (foldl (fn (p, (acc, r)) => let val (fs, r) = feed (r, p) in (acc @ fs, r) end) ([], reader) parts)
    in
      check ("the greeting", size g = 64 andalso String.substring (g, 0, 12) = "\255\000\000\000\000\000\000\000\000\127\003\001"
                             andalso String.substring (g, 12, 4) = "NULL");
      check ("read back", readGreeting g = SOME {major = 3, minor = 1, mechanism = "NULL", server = false});
      check ("a bad signature", readGreeting ("\000" ^ String.extract (g, 1, NONE)) = NONE);
      check ("ZMTP 2 refused", readGreeting (String.substring (g, 0, 10) ^ "\002" ^ String.extract (g, 11, NONE)) = NONE);
      check ("a short frame", encode (Data {more = true, body = "ab"}) = "\001\002ab");
      check ("a long frame", String.substring (encode (Data {more = false, body = CharVector.tabulate (300, fn _ => #"x")}), 0, 9)
                             = "\002\000\000\000\000\000\000\001\044");
      check ("a command", encode (Command {name = "READY", data = ""}) = "\004\006\005READY");
      check ("a message", message ["a", "b"] = "\001\001a\000\001b");
      check ("frames, whole", all [bytes] = frames);
      check ("frames, every split",
             List.all (fn i => all [String.substring (bytes, 0, i), String.extract (bytes, i, NONE)] = frames)
                      (List.tabulate (size bytes + 1, fn i => i)));
      check ("metadata", properties (case ready [("Socket-Type", "REQ"), ("X", "1")] of Command {data, ...} => data | _ => "")
                         = [("Socket-Type", "REQ"), ("X", "1")]);
      check ("malformed", (ignore (feed (reader, "\004\000")); false) handle Malformed _ => true)
    end

  val second = SOME (Time.fromSeconds 5)

  fun until (ss, s) =
    case Zmtp.receive s of
      SOME m => SOME m
    | NONE => (case Zmtp.wait (ss, second) of [] => NONE | _ => Zmtp.receive s)

  fun sockets () =
    let
      val router = Zmtp.bind (Zmtp.Router, {host = "127.0.0.1", port = 0})
      val dealer = Zmtp.connect (Zmtp.Dealer, {host = "127.0.0.1", port = Zmtp.port router}, {identity = SOME "client"})
      val () = Zmtp.send (dealer, ["hello", "world"])
      val got = until ([router, dealer], router)
      val () = Zmtp.send (router, ["client", "back"])
      val back = until ([router, dealer], dealer)
      val rep = Zmtp.bind (Zmtp.Rep, {host = "127.0.0.1", port = 0})
      val req = Zmtp.connect (Zmtp.Req, {host = "127.0.0.1", port = Zmtp.port rep}, {identity = NONE})
      val () = Zmtp.send (req, ["ping"])
      val asked = until ([rep, req], rep)
      val () = Zmtp.send (rep, ["pong"])
      val answered = until ([rep, req], req)
      val pub = Zmtp.bind (Zmtp.Pub, {host = "127.0.0.1", port = 0})
      val sub = Zmtp.connect (Zmtp.Sub, {host = "127.0.0.1", port = Zmtp.port pub}, {identity = NONE})
      val () = Zmtp.subscribe (sub, "a")
      (* the subscription has to arrive before anything is published *)
      fun settle 0 = () | settle k = (ignore (Zmtp.wait ([pub, sub], SOME (Time.fromMilliseconds 20))); settle (k - 1))
      val () = settle 10
      val () = Zmtp.send (pub, ["apple", "1"])
      val () = Zmtp.send (pub, ["banana", "2"])
      val () = Zmtp.send (pub, ["avocado", "3"])
      val first = until ([pub, sub], sub)
      val next = until ([pub, sub], sub)
      val none = (ignore (Zmtp.wait ([pub, sub], SOME (Time.fromMilliseconds 100))); Zmtp.receive sub)
    in
      check ("ROUTER receives with the identity", got = SOME ["client", "hello", "world"]);
      check ("ROUTER sends to the identity", back = SOME ["back"]);
      check ("REQ and REP", asked = SOME ["ping"] andalso answered = SOME ["pong"]);
      check ("PUB and SUB", first = SOME ["apple", "1"] andalso next = SOME ["avocado", "3"] andalso none = NONE);
      check ("SUB does not send", (Zmtp.send (sub, ["x"]); false) handle Zmtp.Error _ => true);
      List.app Zmtp.close [router, dealer, rep, req, pub, sub]
    end

  fun main () =
    (wire (); sockets ();
     print ((if !failures = 0 then "PASS" else "FAIL") ^ " zmtp: " ^ Int.toString (!failures) ^ " failed\n"))
end

val () = ZmtpTest.main ()
