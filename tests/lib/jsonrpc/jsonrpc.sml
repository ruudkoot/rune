(* libraries: random *)
(* JsonRpc against the examples of the JSON-RPC 2.0 specification (its
   section 7), messages written and read back, a server's answers; and
   Framing on every split of a stream, in both framings. *)
structure JsonRpcTest =
struct
  val failures = ref 0
  fun check (name, ok) = if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))

  open JsonRpc
  fun codes text = map (fn Invalid ({code, ...}, _) => code | Message _ => 0) (decode text)

  fun specification () =
    (check ("a call", decode "{\"jsonrpc\": \"2.0\", \"method\": \"subtract\", \"params\": [42, 23], \"id\": 1}"
                      = [Message (Request {id = Number 1, method = "subtract",
                                           params = SOME (Json.Array [Json.Number "42", Json.Number "23"])})]);
     check ("named parameters", decode "{\"jsonrpc\": \"2.0\", \"method\": \"subtract\", \"params\": {\"a\": 1}, \"id\": \"x\"}"
                                = [Message (Request {id = String "x", method = "subtract",
                                                     params = SOME (Json.Object [("a", Json.Number "1")])})]);
     check ("a notification", decode "{\"jsonrpc\": \"2.0\", \"method\": \"update\", \"params\": [1,2]}"
                              = [Message (Notification {method = "update",
                                                        params = SOME (Json.Array [Json.Number "1", Json.Number "2"])})]);
     check ("invalid JSON", codes "{\"jsonrpc\": \"2.0\", \"method\": \"foobar, \"params\": \"bar\", \"baz]" = [parseError]);
     check ("an invalid request", codes "{\"jsonrpc\": \"2.0\", \"method\": 1, \"params\": \"bar\"}" = [invalidRequest]);
     check ("a batch of invalid JSON", codes "[{\"jsonrpc\": \"2.0\", \"method\": \"sum\", \"params\": [1,2,4], \"id\": \"1\"},{\"jsonrpc\": \"2.0\", \"method\"\n]" = [parseError]);
     check ("an empty batch", codes "[]" = [invalidRequest]);
     check ("a batch of a number", codes "[1]" = [invalidRequest]);
     check ("a batch of numbers", codes "[1,2,3]" = [invalidRequest, invalidRequest, invalidRequest]);
     check ("a mixed batch", codes ("[{\"jsonrpc\": \"2.0\", \"method\": \"sum\", \"params\": [1,2,4], \"id\": \"1\"},"
                                    ^ "{\"jsonrpc\": \"2.0\", \"method\": \"notify_hello\", \"params\": [7]},"
                                    ^ "{\"foo\": \"boo\"},"
                                    ^ "{\"jsonrpc\": \"2.0\", \"method\": \"get_data\", \"id\": \"9\"}]")
                             = [0, 0, invalidRequest, 0]);
     check ("the id of an invalid request is kept",
            decode "{\"jsonrpc\": \"2.0\", \"method\": 1, \"id\": 7}"
            = [Invalid ({code = invalidRequest, message = "Invalid Request: a method that is no string", data = NONE},
                        SOME (Number 7))]);
     check ("a version other than 2.0", codes "{\"jsonrpc\": \"1.0\", \"method\": \"m\", \"id\": 1}" = [invalidRequest]);
     check ("a response", decode "{\"jsonrpc\": \"2.0\", \"result\": 19, \"id\": 1}"
                          = [Message (Response {id = SOME (Number 1), outcome = Result (Json.Number "19")})]);
     check ("an error", decode "{\"jsonrpc\": \"2.0\", \"error\": {\"code\": -32601, \"message\": \"Method not found\"}, \"id\": \"1\"}"
                        = [Message (Response {id = SOME (String "1"),
                                              outcome = Error {code = methodNotFound, message = "Method not found", data = NONE}})]))

  fun roundTrip () =
    let
      val ms = [Request {id = Number 1, method = "a", params = NONE},
                Request {id = String "s", method = "b", params = SOME (Json.Array [Json.Null, Json.Bool true])},
                Notification {method = "n", params = SOME (Json.Object [("k", Json.String "v\n")])},
                Response {id = SOME (Number ~5), outcome = Result Json.Null},
                Response {id = NONE, outcome = Error {code = parseError, message = "m", data = SOME (Json.Number "1")}},
                cancel (Number 3)]
    in
      check ("each written and read", List.all (fn m => decode (encode [m]) = [Message m]) ms);
      check ("a batch written and read", decode (encode ms) = map Message ms);
      check ("encode", encode [Notification {method = "exit", params = NONE}] = "{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}")
    end

  fun serving () =
    let
      fun serve ("add", SOME (Json.Array [a, b])) =
            Json.int (valOf (Json.toInt a) + valOf (Json.toInt b))
        | serve ("add", _) = raise Failed {code = invalidParams, message = "two numbers", data = NONE}
        | serve _ = raise Unknown
      fun req (m, p) = Request {id = Number 9, method = m, params = p}
    in
      check ("an answer", answer (serve, req ("add", SOME (Json.Array [Json.int 2, Json.int 3])))
                          = SOME (Response {id = SOME (Number 9), outcome = Result (Json.int 5)}));
      check ("a failure", answer (serve, req ("add", NONE))
                          = SOME (Response {id = SOME (Number 9),
                                            outcome = Error {code = invalidParams, message = "two numbers", data = NONE}}));
      check ("no such method", case answer (serve, req ("sub", NONE)) of
                                 SOME (Response {outcome = Error {code, ...}, ...}) => code = methodNotFound
                               | _ => false);
      check ("a notification has no answer", answer (serve, Notification {method = "add", params = NONE}) = NONE);
      check ("cancel", cancelled (cancel (String "r")) = SOME (String "r") andalso cancelled (req ("x", NONE)) = NONE)
    end

  fun framing () =
    let
      fun all (f, s) =
        let
          fun feedAll parts =
            let val (ms, r) = foldl (fn (p, (acc, r)) => let val (ms, r) = Framing.feed (r, p) in (acc @ ms, r) end)
                                    ([], Framing.reader f) parts
            in (ms, Framing.pending r) end
          fun at i = feedAll [String.substring (s, 0, i), String.extract (s, i, NONE)]
          val whole = feedAll [s]
        in
          if List.all (fn i => at i = whole) (List.tabulate (size s + 1, fn i => i))
             andalso feedAll (map String.str (explode s)) = whole
          then whole else ([], false)
        end
      val bodies = ["{\"a\":1}", "", "x\r\ny", "\226\130\172"]
      val headed = String.concat (map (fn b => Framing.frame (Framing.ContentLength, b)) bodies)
    in
      check ("lines, every split", all (Framing.Lines, "a\r\nb\n\nc\npartial") = (["a", "b", "c"], true));
      check ("Content-Length, every split", all (Framing.ContentLength, headed) = (bodies, false)
                                            andalso bodies <> []);
      check ("Content-Length with another header",
             #1 (Framing.feed (Framing.reader Framing.ContentLength,
                               "Content-Type: x\r\ncontent-length:  3\r\n\r\nabc")) = ["abc"]);
      check ("a header without a length",
             (ignore (Framing.feed (Framing.reader Framing.ContentLength, "X: 1\r\n\r\n")); false)
             handle Framing.Header _ => true)
    end

  fun main () =
    (specification (); roundTrip (); serving (); framing ();
     print ((if !failures = 0 then "PASS" else "FAIL") ^ " jsonrpc: " ^ Int.toString (!failures) ^ " failed\n"))
end

val () = JsonRpcTest.main ()
