(* The kernel of tests/lib/jupyter/interop.sh: Jupyter.serve with a
   language that echoes. Executing code publishes it on stdout and gives
   it reversed as the result; code is complete when it ends with ";". *)
val c = case CommandLine.arguments () of
          [f] => Jupyter.readConnection (let val i = TextIO.openIn f in TextIO.inputAll i before TextIO.closeIn i end)
        | _ => raise Fail "kernel.sml CONNECTION-FILE"
val k = Jupyter.bind c
val count = ref 0
fun respond {msgType = "execute_request", content, publish, ...} =
      let
        val code = case Json.member ("code", content) of SOME (Json.String s) => s | _ => ""
      in
        count := !count + 1;
        publish ("execute_input", Json.Object [("code", Json.String code), ("execution_count", Json.int (!count))]);
        publish ("stream", Json.Object [("name", Json.String "stdout"), ("text", Json.String ("you said: " ^ code))]);
        publish ("execute_result", Json.Object [("execution_count", Json.int (!count)),
                                                ("data", Json.Object [("text/plain", Json.String (String.implode (rev (String.explode code))))]),
                                                ("metadata", Json.Object [])]);
        SOME (Json.Object [("status", Json.String "ok"), ("execution_count", Json.int (!count)),
                           ("user_expressions", Json.Object [])])
      end
  | respond {msgType = "is_complete_request", content, ...} =
      let val code = case Json.member ("code", content) of SOME (Json.String s) => s | _ => ""
      in SOME (Json.Object [("status", Json.String (if String.isSuffix ";" code then "complete" else "incomplete")),
                            ("indent", Json.String "")]) end
  | respond _ = NONE
val () = Jupyter.serve (k, {info = [("implementation", Json.String "echo"), ("implementation_version", Json.String "1"),
                                    ("language_info", Json.Object [("name", Json.String "echo"), ("version", Json.String "1"),
                                                                    ("mimetype", Json.String "text/plain"),
                                                                    ("file_extension", Json.String ".txt")]),
                                    ("banner", Json.String "echo")],
                            respond = respond})
val () = Jupyter.close k
val () = print "kernel: done\n"
