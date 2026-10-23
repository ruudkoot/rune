(* libraries: test/unit random *)
(* Common wire values against the LSP 3.18 contract, including widths
   that do not fit the default integer of a 31-bit SML host. *)
structure LspProtocolTest =
struct
  val check = Expect.that
  structure L = LspProtocol
  structure R = JsonRpc
  fun invalid expectedReply text =
    case L.decode text of L.Invalid {reply, ...} => reply = expectedReply | _ => false
  fun boundary text =
    let val n = valOf (IntInf.fromString text)
        val message = R.Request {id = R.Number n, method = "initialize", params = SOME (Json.Object [])}
    in case L.decode (L.encode message) of L.Message m => m = message | _ => false end
  fun wire () =
    (check ("positive 32-bit boundary", boundary "2147483647");
     check ("negative 32-bit boundary", boundary "-2147483648");
     check ("above 32-bit id refused", invalid true "{\"jsonrpc\":\"2.0\",\"id\":2147483648,\"method\":\"m\"}");
     check ("below 32-bit id refused", invalid true "{\"jsonrpc\":\"2.0\",\"id\":-2147483649,\"method\":\"m\"}");
     check ("batch refused", invalid true "[{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"m\"}]");
     check ("duplicate id refused", invalid true "{\"jsonrpc\":\"2.0\",\"id\":1,\"id\":2,\"method\":\"m\"}");
     check ("mixed request/response refused", invalid true "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"m\",\"result\":null}");
     check ("bad response is not answered", invalid false "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null,\"error\":{}}");
     check ("bad notification is not answered", invalid false "{\"jsonrpc\":\"2.0\",\"method\":\"m\",\"params\":7}");
     check ("wide error is not answered", invalid false "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":2147483648,\"message\":\"m\"}}");
     check ("very large id refused", invalid true ("{\"jsonrpc\":\"2.0\",\"id\":"
          ^ String.implode (List.tabulate (2000, fn _ => #"9")) ^ ",\"method\":\"m\"}"));
     check ("malformed UTF8 not silently widened",
       (ignore (L.encode (R.Notification {method = "\255", params = NONE})); false) handle Domain => true);
     check ("wide outgoing id refused", (ignore (L.encode (R.Request
       {id = R.Number (valOf (IntInf.fromString "2147483648")), method = "m", params = NONE})); false) handle Domain => true))
  fun positions () =
    let
      val zero = {line = IntInf.fromInt 0, character = IntInf.fromInt 0}
      val high = {line = L.maxInteger, character = L.maxInteger}
      val range = {start = zero, stop = high}
    in
      check ("full-width position", L.positionFromJson (L.positionToJson high) = SOME high);
      check ("half-open range", L.rangeFromJson (L.rangeToJson range) = SOME range);
      check ("empty range", L.rangeFromJson (L.rangeToJson {start = high, stop = high}) = SOME {start = high, stop = high});
      check ("negative coordinate refused", L.positionFromJson (Json.decode "{\"line\":0,\"character\":-1}") = NONE);
      check ("duplicate coordinate refused", L.positionFromJson (Json.decode "{\"line\":0,\"line\":1,\"character\":0}") = NONE);
      check ("reversed range refused", L.rangeFromJson (Json.Object
        [("start", L.positionToJson high), ("end", L.positionToJson zero)]) = NONE);
      check ("reversed outgoing range refused", (ignore (L.rangeToJson {start = high, stop = zero}); false) handle Domain => true)
    end
  fun capabilities () =
    let fun encoding text = Option.map L.positionEncoding (L.capabilities (Json.decode text))
        val raw = Json.decode "{\"workspace\":{\"configuration\":true},\"experimental\":{\"future\":3}}"
        val caps = valOf (L.capabilities raw)
    in
      check ("UTF16 fallback", encoding "{}" = SOME L.Utf16);
      check ("UTF8 preferred", encoding "{\"general\":{\"positionEncodings\":[\"utf-32\",\"utf-8\"]}}" = SOME L.Utf8);
      check ("UTF32 offered", encoding "{\"general\":{\"positionEncodings\":[\"utf-32\"]}}" = SOME L.Utf32);
      check ("future encoding fallback", encoding "{\"general\":{\"positionEncodings\":[\"utf-64\"]}}" = SOME L.Utf16);
      check ("invalid encoding list", encoding "{\"general\":{\"positionEncodings\":[7]}}" = NONE);
      check ("capability lookup", L.supports (caps, ["workspace", "configuration"])
             andalso not (L.supports (caps, ["workspace", "workspaceFolders"])));
      check ("extension capabilities retained", L.rawCapabilities caps = raw)
    end
  fun inventory () =
    let
      val methods = LspMethods.all
      val requests = List.filter (fn m : LspMethods.method => #kind m = LspMethods.Request) methods
      val notifications = List.filter (fn m : LspMethods.method => #kind m = LspMethods.Notification) methods
    in
      check ("all protocol messages", length requests = 69 andalso length notifications = 26);
      check ("all declared properties", length LspMethods.properties = 814);
      check ("all enum values", length LspMethods.enumValues = 250);
      check ("inline completion is 3.18", case LspMethods.find "textDocument/inlineCompletion" of
        SOME m => #since m = SOME "3.18.0" andalso #direction m = LspMethods.ClientToServer | NONE => false);
      check ("3.18 range support inventoried", List.exists (fn p : LspMethods.property =>
        #owner p = "DocumentRangeFormattingOptions" andalso #name p = "rangesSupport") LspMethods.properties);
      check ("debug message kind inventoried", List.exists (fn v : LspMethods.enumValue =>
        #owner v = "MessageType" andalso #name v = "Debug" andalso #value v = "5") LspMethods.enumValues)
    end
  fun requests () =
    let
      val table = LspRequests.new {prefix = "test-", maxPending = 2}
      fun id (R.Request {id, ...}) = id | id _ = raise Fail "not a request"
      val a = LspRequests.issue (table, {method = "a", params = NONE, data = "a"})
      val b = LspRequests.issue (table, {method = "b", params = NONE, data = "b"})
      val () = check ("bounded pending requests", (ignore (LspRequests.issue
        (table, {method = "c", params = NONE, data = "c"})); false) handle LspRequests.Full => true)
      val () = check ("duplicate cannot replace ownership", not (LspRequests.reserve (table, id a, "wrong")))
      val answer = R.Response {id = SOME (id b), outcome = R.Result Json.Null}
      val () = check ("out-of-order response", LspRequests.resolve (table, answer) = SOME ("b", R.Result Json.Null))
      val () = check ("one response per request", LspRequests.resolve (table, answer) = NONE)
      val () = check ("cancel owns correct request", LspRequests.cancel (table, id a) = SOME (R.cancel (id a), "a"))
      val () = check ("late cancelled response ignored", LspRequests.resolve (table,
        R.Response {id = SOME (id a), outcome = R.Result Json.Null}) = NONE)
      val () = check ("request ownership released", LspRequests.size table = 0)
      val _ = LspRequests.issue (table, {method = "d", params = NONE, data = "d"})
    in check ("connection cleanup", LspRequests.clear table = ["d"] andalso LspRequests.size table = 0) end
  val tests = Test.describe "lsp" [Test.it "wire" wire, Test.it "positions" positions,
                                 Test.it "capabilities" capabilities, Test.it "inventory" inventory,
                                 Test.it "requests" requests]
end
structure LspProtocolMain = Main (struct val name = "lsp" val tests = LspProtocolTest.tests end)
val () = LspProtocolMain.main ()
