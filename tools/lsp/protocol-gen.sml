(* Deterministic method/property inventory from the pinned LSP metamodel.
   Documentation strings are not copied into generated implementation code. *)
structure LspProtocolGen =
struct
  exception Failed of string
  val pinned = "ce9e95e3c2a1ef333f5b7d64be7c8d31138af736a3d128cd5d99165e9dd26a5d"
  fun need (b, s) = if b then () else raise Failed s
  fun field key v = case Json.member (key, v) of SOME x => x | NONE => raise Failed ("missing " ^ key)
  fun string (Json.String s) = s | string _ = raise Failed "expected a string"
  fun array (Json.Array xs) = xs | array _ = raise Failed "expected an array"
  fun optional key v = case Json.member (key, v) of SOME (Json.String s) => SOME s | NONE => NONE
                     | _ => raise Failed ("invalid " ^ key)
  fun flag key v = case Json.member (key, v) of SOME (Json.Bool b) => b | NONE => false
                 | _ => raise Failed ("invalid " ^ key)
  fun read path = let val s = TextIO.openIn path in TextIO.inputAll s before TextIO.closeIn s end
  fun quote s = "\"" ^ String.translate (fn #"\"" => "\\\"" | #"\\" => "\\\\" | #"\n" => "\\n" | #"\r" => "\\r"
       | #"\t" => "\\t" | c => if Char.ord c < 32 orelse Char.ord c >= 127
         then "\\" ^ StringCvt.padLeft #"0" 3 (Int.toString (Char.ord c)) else str c) s ^ "\""
  fun option NONE = "NONE" | option (SOME s) = "SOME " ^ quote s
  fun boolean true = "true" | boolean false = "false"
  fun sorted key xs =
    let fun insert (x, []) = [x]
          | insert (x, y :: ys) = if String.compare (key x, key y) = LESS then x :: y :: ys else y :: insert (x, ys)
    in List.foldl insert [] xs end
  fun method kind v =
    let val direction = case string (field "messageDirection" v) of
             "clientToServer" => "ClientToServer" | "serverToClient" => "ServerToClient" | "both" => "Both"
           | s => raise Failed ("unknown direction " ^ s)
        val name = string (field "method" v)
    in (name, "{name = " ^ quote name ^ ", direction = " ^ direction ^ ", kind = " ^ kind
       ^ ", clientCapability = " ^ option (optional "clientCapability" v)
       ^ ", serverCapability = " ^ option (optional "serverCapability" v)
       ^ ", since = " ^ option (optional "since" v) ^ ", proposed = " ^ boolean (flag "proposed" v) ^ "}") end
  fun main args =
    let
      val output = ref "lib/lsp/methods.sml"
      val check = ref false
      fun options [] = () | options ("--check" :: xs) = (check := true; options xs)
        | options ("--out" :: p :: xs) = (output := p; options xs)
        | options _ = raise Failed "usage: rune-lsp-protocol [--check] [--out FILE]"
      val () = options args
      val raw = read "tools/lsp/protocol/metaModel-3.18.0.json"
      val () = need (Hex.fromBytes (Sha256.digest raw) = pinned, "metamodel hash differs from the reviewed source")
      val model = Json.decode raw
      val version = string (field "version" (field "metaData" model))
      val () = need (version = "3.18.0", "unexpected protocol version")
      val methods = sorted #1 (List.map (method "Request") (array (field "requests" model))
                        @ List.map (method "Notification") (array (field "notifications" model)))
      fun unique [] = () | unique [_] = ()
        | unique ((a, _) :: (rest as (b, _) :: _)) = (need (a <> b, "duplicate method " ^ a); unique rest)
      val () = unique methods
      val properties = ref [] : (string * string) list ref
      fun wireType owner t =
        case string (field "kind" t) of
          "literal" => fields owner (array (field "properties" (field "value" t)))
        | "array" => wireType (owner ^ "[]") (field "element" t)
        | "map" => wireType (owner ^ "{}") (field "value" t)
        | "or" => items owner (array (field "items" t))
        | "and" => items owner (array (field "items" t))
        | "tuple" => items owner (array (field "items" t))
        | "base" => () | "reference" => () | "stringLiteral" => () | "integerLiteral" => () | "booleanLiteral" => ()
        | kind => raise Failed ("unknown metamodel type kind " ^ kind)
      and items owner ts =
        List.app (fn (t, i) => wireType (owner ^ "[" ^ Int.toString i ^ "]") t)
          (ListPair.zip (ts, List.tabulate (length ts, fn i => i)))
      and fields owner ps = List.app (fn p =>
        let val name = string (field "name" p)
            val value = "{owner = " ^ quote owner ^ ", name = " ^ quote name
              ^ ", optional = " ^ boolean (flag "optional" p) ^ ", since = " ^ option (optional "since" p)
              ^ ", proposed = " ^ boolean (flag "proposed" p) ^ "}"
            val () = properties := (owner ^ "." ^ name, value) :: !properties
        in wireType (owner ^ "." ^ name) (field "type" p) end) ps
      val () = List.app (fn s => fields (string (field "name" s)) (array (field "properties" s)))
                        (array (field "structures" model))
      val () = List.app (fn t => wireType (string (field "name" t)) (field "type" t))
                        (array (field "typeAliases" model))
      val () = List.app (fn m => List.app (fn key => case Json.member (key, m) of NONE => ()
          | SOME t => wireType (string (field "method" m) ^ "." ^ key) t)
            ["params", "result", "partialResult", "errorData", "registrationOptions"])
            (array (field "requests" model) @ array (field "notifications" model))
      val properties = sorted #1 (!properties)
      val () = unique properties
      val enumValues = sorted #1 (List.concat (List.map (fn e =>
        let val owner = string (field "name" e)
        in List.map (fn v =>
             let val name = string (field "name" v)
             in (owner ^ "." ^ name, "{owner = " ^ quote owner ^ ", name = " ^ quote name
                ^ ", value = " ^ quote (Json.encode (field "value" v)) ^ ", since = " ^ option (optional "since" v)
                ^ ", proposed = " ^ boolean (flag "proposed" v) ^ "}") end)
              (array (field "values" e)) end) (array (field "enumerations" model))))
      fun values (name, rows) = "  val " ^ name ^ " =\n    [" ^ String.concatWith ",\n     " (List.map #2 rows) ^ "]\n"
      val generated = "(* Generated from Microsoft's LSP 3.18.0 metamodel by tools/lsp/protocol-gen.sml.\n"
        ^ "   Attribution and CC BY 4.0 license: tools/lsp/protocol/NOTICE.md.\n\n"
        ^ "   Implements: LSP_METHODS *)\nstructure LspMethods :> LSP_METHODS =\nstruct\n"
        ^ "  datatype direction = ClientToServer | ServerToClient | Both\n"
        ^ "  datatype kind = Request | Notification\n"
        ^ "  type method = {name : string, direction : direction, kind : kind, clientCapability : string option,\n"
        ^ "                 serverCapability : string option, since : string option, proposed : bool}\n"
        ^ "  type property = {owner : string, name : string, optional : bool, since : string option, proposed : bool}\n"
        ^ "  type enumValue = {owner : string, name : string, value : string, since : string option, proposed : bool}\n"
        ^ "  val version = " ^ quote version ^ "\n  val sourceHash = " ^ quote pinned ^ "\n"
        ^ values ("all", methods) ^ "  fun find name = List.find (fn (m : method) => #name m = name) all\n"
        ^ values ("properties", properties) ^ values ("enumValues", enumValues) ^ "end\n"
      val existing = (SOME (read (!output)) handle IO.Io _ => NONE)
      val () = if !check then need (existing = SOME generated, "generated LSP inventory is stale")
               else if existing = SOME generated then ()
               else let val stream = TextIO.openOut (!output)
                    in TextIO.output (stream, generated); TextIO.closeOut stream end
    in print ("LSP inventory: " ^ Int.toString (length methods) ^ " methods, "
              ^ Int.toString (length properties) ^ " properties, " ^ Int.toString (length enumValues) ^ " enum values\n") end
end
val () = LspProtocolGen.main (CommandLine.arguments ())
  handle e => (TextIO.output (TextIO.stdErr, "lsp-protocol: " ^ (case e of LspProtocolGen.Failed s => s | _ => General.exnMessage e) ^ "\n");
               OS.Process.exit OS.Process.failure)
