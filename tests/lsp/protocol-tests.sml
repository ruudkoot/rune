(* Independent wire transcripts: framing is assembled/read here without
   using Framing or LspProtocol, so a mutually wrong codec cannot pass. *)
structure LspWireTests =
struct
  open Sh
  exception Failed of string
  fun need (ok, message) = if ok then () else raise Failed message
  val stem = run ^ "/lsp-wire-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
  val dir =
    let val () = mkdirs run
        fun create n = let val p = stem ^ "-" ^ Int.toString n
                       in (OS.FileSys.mkDir p; p) handle e as OS.SysErr _ => if exists p then create (n + 1) else raise e end
    in create 0 end
  fun frame text = "Content-Length: " ^ Int.toString (size text) ^ "\r\n\r\n" ^ text
  fun request id method params = "{\"jsonrpc\":\"2.0\",\"id\":" ^ id ^ ",\"method\":\"" ^ method ^ "\""
      ^ (case params of NONE => "" | SOME p => ",\"params\":" ^ p) ^ "}"
  fun notify method params = "{\"jsonrpc\":\"2.0\",\"method\":\"" ^ method ^ "\""
      ^ (case params of NONE => "" | SOME p => ",\"params\":" ^ p) ^ "}"
  val init = request "1" "initialize" (SOME "{\"capabilities\":{}}")
  val initialized = notify "initialized" (SOME "{}")
  val shutdown = request "2" "shutdown" NONE
  val exit = notify "exit" NONE
  fun take text =
    let val (header, suffix) = Substring.position "\r\n\r\n" (Substring.full text)
    in if Substring.isEmpty suffix then NONE else
      let val head = Substring.string header
          val () = need (String.isPrefix "Content-Length: " head, "server output is not a Content-Length frame")
          val digits = String.extract (head, size "Content-Length: ", NONE)
          val () = need (digits <> "" andalso CharVector.all Char.isDigit digits, "server wrote a malformed length")
          val count = case Int.fromString digits of SOME n => n | NONE => raise Failed "server wrote an oversized length"
          val body = Substring.string (Substring.triml 4 suffix)
      in if size body < count then NONE
         else SOME (Json.decode (String.substring (body, 0, count)), String.extract (body, count, NONE)) end
    end
  fun messages "" = []
    | messages text = case take text of SOME (message, rest) => message :: messages rest
                                      | NONE => raise Failed "server output ended within a frame"
  fun field key v = case Json.member (key, v) of SOME x => x | NONE => raise Failed ("missing response member " ^ key)
  fun code value = Json.toInt (field "code" (field "error" value))
  fun responses xs = List.filter (fn v => isSome (Json.member ("result", v)) orelse isSome (Json.member ("error", v))) xs
  fun execute name flags wire expected =
    let val input = dir ^ "/" ^ name ^ ".stdin"
        val output = dir ^ "/" ^ name ^ ".stdout"
        val errors = dir ^ "/" ^ name ^ ".stderr"
        val () = write (input, wire)
        val status = exec {cmd = fromRoot "bin/runelsp" :: flags, dir = SOME root,
                           stdin = input, stdout = output, stderr = errors, timeout = 30}
        val () = need ((status = 0) = expected, name ^ ": unexpected process status " ^ Int.toString status ^ ": " ^ read errors)
    in (messages (read output), read errors) end
  fun batch name inputs expected = execute name [] (String.concat (List.map frame inputs)) expected
  fun basic () =
    let val (output, _) = batch "basic" [init, initialized, request "\"query\"" "textDocument/prepareTypeHierarchy" (SOME "{}"), shutdown, exit] true
        val rows = responses output
        val () = need (length rows = 3, "basic transcript response count differs")
        val result = field "result" (hd rows)
        val caps = field "capabilities" result
        val () = need (field "positionEncoding" caps = Json.String "utf-16" andalso
                       field "change" (field "textDocumentSync" caps) = Json.int 2 andalso
                       field "openClose" (field "textDocumentSync" caps) = Json.Bool true,
                       "document capability negotiation differs")
        val () = need (code (List.nth (rows, 1)) = SOME ~32601 andalso field "id" (List.nth (rows, 1)) = Json.String "query",
                       "unimplemented provider was advertised or its request id changed")
    in need (field "result" (List.nth (rows, 2)) = Json.Null, "shutdown did not return null") end
  fun lifecycle () =
    let
      val modern = request "2147483647" "initialize" (SOME
        "{\"capabilities\":{\"general\":{\"positionEncodings\":[\"utf-32\",\"utf-8\"]}},\"workDoneToken\":\"boot\"}")
      val (output, _) = batch "lifecycle" [request "0" "m" NONE, modern, initialized,
        request "-2147483648" "m" NONE, request "3" "initialize" (SOME "{\"capabilities\":{}}"),
        shutdown, request "5" "m" NONE, exit] true
      val rows = responses output
      val () = need (length rows = 6, "lifecycle response count differs")
      val () = need (code (hd rows) = SOME ~32002, "pre-initialization request was accepted")
      val () = need (field "id" (List.nth (rows, 1)) = Json.Number "2147483647", "large positive id was truncated")
      val () = need (field "positionEncoding" (field "capabilities" (field "result" (List.nth (rows, 1)))) = Json.String "utf-8",
                     "modern client encoding was not negotiated")
      val () = need (field "id" (List.nth (rows, 2)) = Json.Number "-2147483648", "large negative id was truncated")
      val () = need (code (List.nth (rows, 3)) = SOME ~32600 andalso code (List.nth (rows, 5)) = SOME ~32600,
                     "duplicate initialization or post-shutdown request was accepted")
      val progress = List.filter (fn v => Json.member ("method", v) = SOME (Json.String "$/progress")) output
      val () = need (length progress = 2, "initialize progress is missing")
      val kinds = List.map (fn v => field "kind" (field "value" (field "params" v))) progress
    in need (kinds = [Json.String "begin", Json.String "end"], "progress begin/end sequence differs") end
  fun malformed () =
    let
      val (output, _) = batch "batch" ["[" ^ init ^ "]", init, initialized, shutdown, exit] true
      val rows = responses output
      val () = need (length rows = 3 andalso code (hd rows) = SOME ~32600
                     andalso isSome (Json.member ("result", List.nth (rows, 1))), "LSP batch was executed")
      val (output, _) = batch "parse-error" ["{", init, initialized, shutdown, exit] true
      val () = need (length (responses output) = 3 andalso code (hd output) = SOME ~32700,
                     "malformed JSON poisoned the next complete frame")
      val (output, _) = batch "notifications" [init, initialized,
        notify "ignored" (SOME "7"), notify "ignored" NONE,
        notify "$/cancelRequest" (SOME "{\"id\":\"unknown\"}"),
        notify "window/workDoneProgress/cancel" (SOME "{\"token\":\"unknown\"}"),
        "{\"jsonrpc\":\"2.0\",\"id\":\"orphan\",\"result\":null,\"error\":{}}", shutdown, exit] true
      val () = need (length output = 2, "a notification or malformed response was answered")
      val (output, _) = batch "shutdown-notification" [init, initialized, notify "shutdown" NONE, exit] false
      val () = need (length output = 1, "shutdown notification changed lifecycle state")
      val (output, _) = batch "notification-as-request" [init, initialized, request "7" "initialized" (SOME "{}"), shutdown, exit] true
    in need (code (List.nth (responses output, 1)) = SOME ~32600, "notification method accepted as request") end
  fun transport () =
    let
      val (output, errors) = execute "body-limit" ["--max-message-bytes", "16"] "Content-Length: 17\r\n\r\n" false
      val () = need (null output andalso String.isSubstring "exceeds" errors, "body bound did not reject the header")
      val (output, _) = execute "duplicate-length" [] "Content-Length: 2\r\ncontent-length: 2\r\n\r\n{}" false
      val () = need (null output, "ambiguous transport header produced a response")
      val (output, errors) = execute "truncated" [] "Content-Length: 2\r\n\r\n{" false
      val () = need (null output andalso String.isSubstring "truncated" errors, "truncated body was ignored")
      val (output, _) = execute "header-limit" [] (String.implode (List.tabulate (8193, fn _ => #"A"))) false
      val () = need (null output, "oversized header produced protocol output")
      val (output, _) = batch "early-exit" [exit] false
      val () = need (null output, "early exit produced output")
      val (output, _) = batch "eof" [] true
    in need (null output, "empty transport produced output") end
  fun tracing () =
    let val (output, _) = batch "trace" [init, initialized, notify "$/setTrace" (SOME "{\"value\":\"verbose\"}"),
          request "9" "ignored" NONE, notify "$/setTrace" (SOME "{\"value\":\"off\"}"), shutdown, exit] true
        val traces = List.filter (fn v => Json.member ("method", v) = SOME (Json.String "$/logTrace")) output
    in need (not (null traces) andalso length (responses output) = 3, "trace traffic corrupted response ownership") end
  fun generatedInventory () =
    let val generated = dir ^ "/inventory.sml"
        fun invoke args = exec {cmd = fromRoot "bin/rune-lsp-protocol" :: args, dir = SOME root,
                               stdin = "", stdout = dir ^ "/inventory.stdout", stderr = dir ^ "/inventory.stderr", timeout = 30}
        val () = need (invoke ["--out", generated] = 0, "inventory generation failed")
        val () = need (invoke ["--check", "--out", generated] = 0, "fresh generated inventory is stale")
        val () = write (generated, read generated ^ "\n(* planted stale output *)\n")
    in need (invoke ["--check", "--out", generated] <> 0
             andalso String.isSubstring "stale" (read (dir ^ "/inventory.stderr")), "stale inventory was accepted") end
  fun interactive () =
    let
      val incoming = Posix.IO.pipe ()
      val outgoing = Posix.IO.pipe ()
      val err = Posix.FileSys.creat (dir ^ "/interactive.stderr",
        Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr])
      val handles = [#infd incoming, #outfd incoming, #infd outgoing, #outfd outgoing, err]
      val () = List.app (fn f => Posix.IO.setfd (f, Posix.IO.FD.flags [Posix.IO.FD.cloexec])) handles
      fun fd f = SysWord.toInt (Posix.FileSys.fdToWord f)
      fun close f = Posix.IO.close f handle OS.SysErr _ => ()
      val pid = (Subprocess.spawn {program = fromRoot "bin/runelsp", args = [fromRoot "bin/runelsp"], env = NONE,
        search = false, dir = SOME root, stdin = SOME (fd (#infd incoming)), stdout = SOME (fd (#outfd outgoing)),
        stderr = SOME (fd err), group = true, limits = Subprocess.unlimited}
        handle e => (List.app close handles; raise e))
      val () = List.app close [#infd incoming, #outfd outgoing, err]
      val pending = ref ""
      val ended = ref false
      fun send text =
        let val bytes = Byte.stringToBytes (frame text)
            fun loop i = if i = Word8Vector.length bytes then ()
              else let val n = Posix.IO.writeVec (#outfd incoming, Word8VectorSlice.slice (bytes, i, SOME 1))
                   in need (n = 1, "interactive write failed"); loop (i + 1) end
        in loop 0 end
      fun receive () =
        let val deadline = Time.+ (Runtime.clock (), Time.fromSeconds 10)
            fun loop () = case take (!pending) of
                SOME (value, rest) => (pending := rest; value)
              | NONE =>
                  let val () = need (Time.< (Runtime.clock (), deadline), "server waits for EOF or a full read buffer")
                      val poll = valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD (#infd outgoing)))
                      val ready = OS.IO.poll ([OS.IO.pollIn poll], SOME (Time.fromMilliseconds 20))
                  in if null ready then loop () else
                       let val bytes = Posix.IO.readVec (#infd outgoing, 4096)
                           val () = need (Word8Vector.length bytes > 0, "interactive server ended early")
                       in pending := !pending ^ Byte.bytesToString bytes; loop () end end
        in loop () end
      fun cleanup () = if !ended then () else
        (List.app close handles; (Subprocess.kill (pid, Posix.Signal.kill) handle OS.SysErr _ => ());
         ignore (Subprocess.wait (SOME pid)) handle OS.SysErr _ => ())
      fun work () =
        let val () = send (request "\"\240\159\152\128\"" "initialize" (SOME "{\"capabilities\":{}}"))
            val answer = receive ()
            val () = need (field "id" answer = Json.String "\240\159\152\128", "UTF8 id byte length was not preserved")
            val () = send initialized
            val () = send shutdown
            val () = need (field "result" (receive ()) = Json.Null, "interactive shutdown failed")
            val () = send exit
            val () = List.app close [#outfd incoming, #infd outgoing]
            val result = Subprocess.wait (SOME pid)
            val () = ended := true
        in need (#status result = Posix.Process.W_EXITED, "interactive server did not exit normally") end
    in work () handle e => (cleanup (); raise e) end
  fun synchronization () =
    let
      val start=request "1" "initialize" (SOME "{\"capabilities\":{},\"trace\":\"messages\"}")
      fun doc method body=notify ("textDocument/" ^ method) (SOME body)
      val openDocument=doc "didOpen"
        "{\"textDocument\":{\"uri\":\"file:///a.sml\",\"languageId\":\"sml\",\"version\":1,\"text\":\"a\\ud801\\udc00b\\r\\n\"}}"
      val sequential=doc "didChange"
        "{\"textDocument\":{\"uri\":\"file:///a.sml\",\"version\":2},\"contentChanges\":[{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":3}},\"text\":\"x\"},{\"range\":{\"start\":{\"line\":0,\"character\":2},\"end\":{\"line\":0,\"character\":3}},\"text\":\"z\"}]}"
      val malformed=doc "didChange"
        "{\"textDocument\":{\"uri\":\"file:///a.sml\",\"version\":3},\"contentChanges\":[{\"text\":\"\\ud801\\udc00\"},{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":2}},\"text\":\"bad\"}]}"
      val incremental=doc "didChange"
        "{\"textDocument\":{\"uri\":\"file:///a.sml\",\"version\":4},\"contentChanges\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":1}},\"text\":\"x\"}]}"
      val replacement=doc "didChange"
        "{\"textDocument\":{\"uri\":\"file:///a.sml\",\"version\":5},\"contentChanges\":[{\"text\":\"synchronized\"}]}"
      val save=doc "didSave" "{\"textDocument\":{\"uri\":\"file:///a.sml\"},\"text\":\"older saved text\"}"
      val willSave=doc "willSave" "{\"textDocument\":{\"uri\":\"file:///a.sml\"},\"reason\":1}"
      val close=doc "didClose" "{\"textDocument\":{\"uri\":\"file:///a.sml\"}}"
      val (rows,errors)=batch "synchronization"
        [start,initialized,openDocument,sequential,malformed,incremental,replacement,
         incremental,willSave,save,close,openDocument,close,shutdown,exit] true
      val ()=need (length (responses rows)=2,"synchronization notifications received responses")
      val logs=List.mapPartial (fn row =>
        case Json.member ("method",row) of SOME (Json.String "$/logTrace") =>
          (case Json.member ("message",field "params" row) of SOME (Json.String text) => SOME text | _ => NONE)
        | _ => NONE) rows
      val events=List.filter (fn text => List.exists (fn prefix => String.isPrefix prefix text)
        ["opened ","changed ","closed ","will save ","saved "]) logs
      val expected=["opened file:///a.sml (version 1)","changed file:///a.sml (version 2)",
        "changed file:///a.sml (version 5)","will save file:///a.sml (version 5)",
        "saved file:///a.sml (version 5)","closed file:///a.sml (version 5)",
        "opened file:///a.sml (version 1)","closed file:///a.sml (version 1)"]
    in need (events=expected,"document synchronization trace differs");
       need (String.isSubstring "inside a character" errors andalso String.isSubstring "requires a full replacement" errors
         andalso String.isSubstring "stale document version" errors,"synchronization errors were not diagnosed") end
  fun workspaceRequests () =
    let val start=request "1" "initialize" (SOME
          "{\"workspaceFolders\":[{\"uri\":\"file:///rune-fixture\",\"name\":\"fixture\"}],\"capabilities\":{\"workspace\":{\"configuration\":true,\"didChangeWatchedFiles\":{\"dynamicRegistration\":true,\"relativePatternSupport\":true}}}}")
        val configured="{\"jsonrpc\":\"2.0\",\"id\":\"runelsp-ws-0\",\"result\":[{}]}"
        val registered="{\"jsonrpc\":\"2.0\",\"id\":\"runelsp-ws-1\",\"result\":null}"
        val removed=notify "workspace/didChangeWorkspaceFolders" (SOME
          "{\"event\":{\"added\":[],\"removed\":[{\"uri\":\"file:///rune-fixture\",\"name\":\"fixture\"}]}}")
        val unregistered="{\"jsonrpc\":\"2.0\",\"id\":\"runelsp-ws-2\",\"result\":null}"
        val (rows,errors)=batch "workspace-requests" [start,initialized,configured,registered,removed,unregistered,shutdown,exit] true
        val requests=List.filter (fn value => isSome (Json.member ("method",value)) andalso isSome (Json.member ("id",value))) rows
        val methods=List.map (field "method") requests
        val ()=need (methods=List.map Json.String ["workspace/configuration","client/registerCapability","client/unregisterCapability"],
          "workspace server requests differ")
        val ()=need (length (responses rows)=2 andalso errors="","workspace replies or notification handling differs")
        val configuration=field "params" (hd requests)
        val ()=need (field "items" configuration=Json.Array [Json.Object [("scopeUri",Json.String "file:///rune-fixture"),("section",Json.String "runelsp")]],
          "configuration scope was not preserved")
        val registration=case field "registrations" (field "params" (List.nth (requests,1))) of Json.Array [value] => value
          | _ => raise Failed "missing watch registration"
        val unregistration=case field "unregisterations" (field "params" (List.nth (requests,2))) of Json.Array [value] => value
          | _ => raise Failed "missing watch unregistration"
    in need (field "id" registration=field "id" unregistration,"watch registration leaked after folder removal") end
  fun main () =
    (basic (); lifecycle (); malformed (); transport (); tracing (); generatedInventory (); interactive ();synchronization ();workspaceRequests ();
     say "PASS lsp-wire: lifecycle, integer ids, progress, malformed input, bounds, tracing and interactive stdio\n")
end
val () = LspWireTests.main ()
  handle e => (TextIO.output (TextIO.stdErr, "FAIL lsp-wire: " ^ (case e of LspWireTests.Failed s => s | _ => General.exnMessage e) ^ "\n");
               OS.Process.exit OS.Process.failure)
