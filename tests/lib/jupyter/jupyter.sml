(* libraries: test/unit *)
(* Jupyter: the connection file, the signature of a message (against
   Python's hmac), messages written and read back, and what is refused.
   tests/lib/jupyter/interop.sh drives a kernel with a client written from
   the messaging specification in Python. *)
structure JupyterTest =
struct
  val check = Expect.that

  val header = {msgId = "1", session = "s", username = "u", date = "d", msgType = "kernel_info_request", version = "5.4"}
  val m = {identities = ["peer"], header = header, parent = Json.Object [], metadata = Json.Object [],
           content = Json.Object [("code", Json.String "1 + 1;")], buffers = ["\000\001"]}

  fun connection () =
    let
      val c = Jupyter.readConnection
                "{\"shell_port\": 1, \"iopub_port\": 2, \"stdin_port\": 3, \"control_port\": 4, \"hb_port\": 5, \"ip\": \"127.0.0.1\", \"key\": \"k\", \"transport\": \"tcp\", \"signature_scheme\": \"hmac-sha256\", \"kernel_name\": \"rune\"}"
    in
      check ("the connection file", #shell c = 1 andalso #heartbeat c = 5 andalso #key c = "k" andalso #ip c = "127.0.0.1");
      check ("a connection file without ports", (ignore (Jupyter.readConnection "{}"); false) handle Jupyter.Connection _ => true)
    end

  fun signatures () =
    (check ("the signature, as Python's hmac makes it",
            Jupyter.sign ("secret", [Json.encode (Jupyter.headerJson header), "{}", "{}", "{}"])
            = "0d6348974bee3be88c2a4f57c3392d157b56caa910d0f4ffe2f39f52ebe64b11");
     check ("no key, no signature", Jupyter.sign ("", ["a"]) = ""))

  fun messages () =
    let
      val parts = Jupyter.encode "secret" m
    in
      check ("the parts on the wire", List.nth (parts, 1) = "<IDS|MSG>" andalso hd parts = "peer" andalso List.last parts = "\000\001");
      check ("written and read back", Jupyter.decode "secret" parts = SOME m);
      check ("another key refused", Jupyter.decode "other" parts = NONE);
      check ("a changed content refused",
             Jupyter.decode "secret" (List.take (parts, 6) @ ["{\"code\":\"2\"}"] @ List.drop (parts, 7)) = NONE);
      check ("no delimiter refused", Jupyter.decode "secret" (List.filter (fn p => p <> "<IDS|MSG>") parts) = NONE)
    end

  val tests =
    Test.describe "jupyter"
      [Test.it "connection" connection, Test.it "signature" signatures, Test.it "messages" messages]
end

structure JupyterMain = Main (struct val name = "jupyter" val tests = JupyterTest.tests end)
val () = JupyterMain.main ()
