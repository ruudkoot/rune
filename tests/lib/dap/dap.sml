(* Dap: the messages of the protocol's overview, as VS Code's adapters
   exchange them, read and written back; a session of messages framed
   and read back in pieces; replies and the events. *)
structure DapTest =
struct
  val failures = ref 0
  fun check (name, ok) = if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))

  open Dap

  val texts = [
    "{\"seq\":1,\"type\":\"request\",\"command\":\"initialize\",\"arguments\":{\"adapterID\":\"rune\",\"linesStartAt1\":true}}",
    "{\"seq\":1,\"type\":\"response\",\"request_seq\":1,\"success\":true,\"command\":\"initialize\",\"body\":{\"supportsConfigurationDoneRequest\":true}}",
    "{\"seq\":2,\"type\":\"event\",\"event\":\"initialized\"}",
    "{\"seq\":3,\"type\":\"request\",\"command\":\"setBreakpoints\",\"arguments\":{\"source\":{\"path\":\"a.sml\"},\"breakpoints\":[{\"line\":3}]}}",
    "{\"seq\":4,\"type\":\"event\",\"event\":\"stopped\",\"body\":{\"reason\":\"breakpoint\",\"threadId\":1}}",
    "{\"seq\":5,\"type\":\"response\",\"request_seq\":4,\"success\":false,\"command\":\"evaluate\",\"message\":\"unbound\"}"]

  fun readBack () =
    (check ("each read and written back",
            List.all (fn t => case decode t of SOME m => Json.encode (toJson m) = t | NONE => false) texts);
     check ("not messages", decode "{\"seq\":1}" = NONE andalso decode "[]" = NONE andalso decode "{" = NONE
                            andalso decode "{\"seq\":1,\"type\":\"response\",\"command\":\"x\"}" = NONE))

  fun framed () =
    let
      val ms = List.mapPartial decode texts
      val wire = String.concat (map encode ms)
      fun read parts =
        #1 (foldl (fn (p, (acc, r)) => let val (bs, r) = Framing.feed (r, p) in (acc @ bs, r) end)
                  ([], Framing.reader Framing.ContentLength) parts)
      fun chunks (s, n) = if size s <= n then [s] else String.substring (s, 0, n) :: chunks (String.extract (s, n, NONE), n)
    in
      check ("a session on the wire", List.mapPartial decode (read [wire]) = ms);
      check ("in pieces", List.all (fn n => List.mapPartial decode (read (chunks (wire, n))) = ms) [1, 2, 7, 64])
    end

  fun replies () =
    let val r = Request {seq = 7, command = "threads", arguments = NONE}
    in
      check ("reply", reply {seq = 9, request = r, body = NONE}
                      = SOME (Response {seq = 9, requestSeq = 7, success = true, command = "threads", message = NONE, body = NONE}));
      check ("refuse", case refuse {seq = 9, request = r, message = "no"} of
                         SOME (Response {success = false, message = SOME "no", requestSeq = 7, ...}) => true
                       | _ => false);
      check ("no reply to an event", reply {seq = 1, request = initialized 1, body = NONE} = NONE);
      check ("events", Json.encode (toJson (stopped {seq = 3, reason = "step", threadId = 1, text = NONE}))
                       = "{\"seq\":3,\"type\":\"event\",\"event\":\"stopped\",\"body\":{\"reason\":\"step\",\"threadId\":1}}"
                       andalso Json.encode (toJson (exited {seq = 4, exitCode = 0}))
                               = "{\"seq\":4,\"type\":\"event\",\"event\":\"exited\",\"body\":{\"exitCode\":0}}")
    end

  fun main () =
    (readBack (); framed (); replies ();
     print ((if !failures = 0 then "PASS" else "FAIL") ^ " dap: " ^ Int.toString (!failures) ^ " failed\n"))
end

val () = DapTest.main ()
