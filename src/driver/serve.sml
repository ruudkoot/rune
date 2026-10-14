(* The compiler as a service (the incremental roadmap's M12; a prototype):
   `rune --serve [OPTION...]` reads requests on standard input and writes
   their answers on standard output, one JSON-RPC 2.0 message per line, as
   the IDE's service transport is (docs/plans/ide.md); what it logs goes to
   standard error. A request names the files of a program in order and the
   text of one of them as an editor has it, which is compiled in place of
   the file's:

     initialize   {}                                -> {name, version, methods}
     diagnostics  {files, path, text}               -> {diagnostics: [{severity,
                                                        path, start, stop, line,
                                                        column, message}]}
     hover        {files, path, text, offset}       -> {name, type, start, stop}
                                                       or null
     shutdown     {}                                -> null, and the service ends

   Offsets are bytes of the text. Each request is answered by a child,
   forked for it: it compiles the program in units through the cache with
   the options the service was started with, as far as types (the Basis
   from the frozen cache, the program's units from the project's), answers
   and ends, so that nothing of one request is left for the next. *)
structure Serve =
struct
  (* ---- JSON ---- *)

  datatype json = Null | Bool of bool | Num of string | Str of string | Arr of json list | Obj of (string * json) list

  exception Bad of string

  fun parse (s : string) : json =
    let
      val n = String.size s
      fun at i = if i < n then String.sub (s, i) else #"\000"
      fun skip i = if i < n andalso Char.isSpace (at i) then skip (i + 1) else i
      fun hex4 i =
        case StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (s, i, 4)) handle Subscript => NONE of
          SOME c => c
        | NONE => raise Bad "a \\u escape"
      (* a code point as UTF-8 *)
      fun utf8 c =
        if c < 0x80 then String.str (Char.chr c)
        else if c < 0x800 then String.implode [Char.chr (0xC0 + c div 64), Char.chr (0x80 + c mod 64)]
        else if c < 0x10000 then
          String.implode [Char.chr (0xE0 + c div 4096), Char.chr (0x80 + (c div 64) mod 64), Char.chr (0x80 + c mod 64)]
        else String.implode [Char.chr (0xF0 + c div 262144), Char.chr (0x80 + (c div 4096) mod 64),
                             Char.chr (0x80 + (c div 64) mod 64), Char.chr (0x80 + c mod 64)]
      (* \u escapes from i: a code point, one of beyond 16 bits as a pair of
         surrogates, and where the next escape begins *)
      fun escape i =
        let val c = hex4 i
        in
          if c >= 0xD800 andalso c < 0xDC00 andalso at (i + 4) = #"\\" andalso at (i + 5) = #"u" then
            let val d = hex4 (i + 6)
            in
              if d >= 0xDC00 andalso d < 0xE000 then (0x10000 + (c - 0xD800) * 1024 + (d - 0xDC00), i + 10)
              else (c, i + 4)
            end
          else (c, i + 4)
        end
      fun str (i, acc) =
        case at i of
          #"\"" => (String.concat (List.rev acc), i + 1)
        | #"\\" =>
            (case at (i + 1) of
               #"n" => str (i + 2, "\n" :: acc) | #"t" => str (i + 2, "\t" :: acc) | #"r" => str (i + 2, "\r" :: acc)
             | #"b" => str (i + 2, "\b" :: acc) | #"f" => str (i + 2, "\f" :: acc)
             | #"u" => let val (c, j) = escape (i + 2) in str (j, utf8 c :: acc) end
             | c => str (i + 2, String.str c :: acc))
        | #"\000" => raise Bad "a string that does not end"
        | c => str (i + 1, String.str c :: acc)
      fun value i =
        let val i = skip i
        in
          case at i of
            #"{" =>
              let
                fun fields (i, acc) =
                  let val i = skip i
                  in
                    if at i = #"}" then (Obj (List.rev acc), i + 1)
                    else
                      let
                        val i = if at i = #"," then skip (i + 1) else i
                        val (k, i) = if at i = #"\"" then str (i + 1, []) else raise Bad "a key"
                        val i = skip i
                        val i = if at i = #":" then i + 1 else raise Bad "a colon"
                        val (v, i) = value i
                      in fields (i, (k, v) :: acc) end
                  end
              in fields (i + 1, []) end
          | #"[" =>
              let
                fun items (i, acc) =
                  let val i = skip i
                  in
                    if at i = #"]" then (Arr (List.rev acc), i + 1)
                    else let val i = if at i = #"," then i + 1 else i
                             val (v, i) = value i
                         in items (i, v :: acc) end
                  end
              in items (i + 1, []) end
          | #"\"" => let val (v, i) = str (i + 1, []) in (Str v, i) end
          | #"t" => (Bool true, i + 4)
          | #"f" => (Bool false, i + 5)
          | #"n" => (Null, i + 4)
          | _ =>
              let fun num j = if j < n andalso (Char.isDigit (at j) orelse Char.contains "+-.eE" (at j)) then num (j + 1) else j
                  val j = num i
              in if j = i then raise Bad "a value" else (Num (String.substring (s, i, j - i)), j) end
        end
    in #1 (value 0) end

  fun quote (s : string) : string =
    "\"" ^ String.translate (fn #"\"" => "\\\"" | #"\\" => "\\\\" | #"\n" => "\\n" | #"\r" => "\\r" | #"\t" => "\\t"
                              | c => if Char.ord c < 32 then "\\u" ^ StringCvt.padLeft #"0" 4 (Int.fmt StringCvt.HEX (Char.ord c))
                                     else String.str c) s ^ "\""

  fun show (j : json) : string =
    case j of
      Null => "null"
    | Bool b => if b then "true" else "false"
    | Num s => s
    | Str s => quote s
    | Arr js => "[" ^ String.concatWith "," (List.map show js) ^ "]"
    | Obj fs => "{" ^ String.concatWith "," (List.map (fn (k, v) => quote k ^ ":" ^ show v) fs) ^ "}"

  fun field (Obj fs, k) = (case List.find (fn (k', _) => k' = k) fs of SOME (_, v) => v | NONE => Null)
    | field _ = Null
  fun int n = Num (if n < 0 then "-" ^ Int.toString (~ n) else Int.toString n)
  fun strings j = case j of Arr js => List.mapPartial (fn Str s => SOME s | _ => NONE) js | _ => []

  (* ---- the answers ---- *)

  (* the program compiled as far as types, its file `path` the text given *)
  fun check (options : string list, params : json) : unit =
    let
      val files = strings (field (params, "files"))
      val () = case (field (params, "path"), field (params, "text")) of
                 (Str p, Str t) => Source.overlays := StringMap.insert (!Source.overlays, p, t)
               | _ => ()
      val () = Error.keep := true
      val () = Main.keepSyntax := true
    in
      ignore (Main.main ("rune", options @ ["--units", "--typecheck-only"] @ files))
    end

  fun position (sp : Source.span) =
    case Source.lineColOf sp of SOME (_, l, c) => [("line", int l), ("column", int c)] | NONE => []

  fun diagnostics () : json =
    Obj [("diagnostics",
          Arr (List.rev (List.map (fn (severity, sp : Source.span, msg) =>
                                     Obj ([("severity", Str severity), ("path", Str (#file sp)), ("start", int (#start sp)),
                                           ("stop", int (#stop sp))] @ position sp @ [("message", Str msg)]))
                                  (!Error.kept))))]

  (* the innermost variable of the declarations of the file whose span
     holds the offset, with its type: what hover answers, and what the REPL's
     engine answers typeAt with (src/repl/engine.sml) *)
  fun variableAt (syntax : (string * Ast.dec list) list, path : string, offset : int)
      : (string * Types.ty * Source.span) option =
    let
      val best : (string * Types.ty * Source.span) option ref = ref NONE
      fun consider (name, ty, sp : Source.span) =
        if #file sp = path andalso #start sp <= offset andalso offset < #stop sp then
          case !best of
            SOME (_, _, b) => if #stop sp - #start sp < #stop b - #start b then best := SOME (name, ty, sp) else ()
          | NONE => best := SOME (name, ty, sp)
        else ()
      fun tyOf v = case v of
                     Ast.VLocal (_, t) => t | Ast.VGlobal (_, t) => t | Ast.VCon (_, t) => t | Ast.VExn (_, t) => t
                   | Ast.VBuiltin (_, t) => t | Ast.VConVal (_, t) => t | Ast.VExnVal (_, t) => t
      fun exp e =
        case e of
          Ast.EVar ((p, x), ref (SOME v), sp) => consider (String.concatWith "." (p @ [x]), tyOf v, sp)
        | Ast.ERecord (fs, _) => List.app (exp o #2) fs
        | Ast.ETuple (es, _) => List.app exp es
        | Ast.EList (es, _, _) => List.app exp es
        | Ast.ESeq (es, _) => List.app exp es
        | Ast.ELet (ds, e, _) => (List.app dec ds; exp e)
        | Ast.EApp (a, b, _) => (exp a; exp b)
        | Ast.ETyped (e, _, _) => exp e
        | Ast.EAndalso (a, b, _) => (exp a; exp b)
        | Ast.EOrelse (a, b, _) => (exp a; exp b)
        | Ast.EHandle (e, ms, _) => (exp e; List.app (exp o #2) ms)
        | Ast.ERaise (e, _) => exp e
        | Ast.EIf (a, b, c, _) => (exp a; exp b; exp c)
        | Ast.EWhile (a, b, _) => (exp a; exp b)
        | Ast.ECase (e, ms, _) => (exp e; List.app (exp o #2) ms)
        | Ast.EFn (ms, _, _) => List.app (exp o #2) ms
        | _ => ()
      and dec d =
        case d of
          Ast.DVal (_, bs, _) => List.app (exp o #2) bs
        | Ast.DValRec (_, bs, _) => List.app (exp o #2) bs
        | Ast.DFun (_, fs, _) => List.app (fn (f : Ast.fundef) => List.app (exp o #body) (#clauses f)) fs
        | Ast.DAbstype (_, _, ds, _) => List.app dec ds
        | Ast.DLocal (a, b, _) => (List.app dec a; List.app dec b)
        | Ast.DStructure (bs, _) => List.app (strexp o #strexp) bs
        | Ast.DFunctor (bs, _) => List.app (strexp o #body) bs
        | _ => ()
      and strexp s =
        case s of
          Ast.StrStruct (ds, _) => List.app dec ds
        | Ast.StrAscribe (s, _, _, _) => strexp s
        | Ast.StrLet (ds, s, _) => (List.app dec ds; strexp s)
        | Ast.StrExport (_, _, s, _, _) => strexp s
        | _ => ()
      val () = List.app (fn (n, ds) => if n = path then List.app dec ds else ()) syntax
    in
      !best
    end

  (* the innermost variable of the file whose span holds the offset *)
  fun hover (path : string, offset : int) : json =
    case variableAt (!Main.keptSyntax, path, offset) of
      SOME (name, ty, sp) => Obj [("name", Str name), ("type", Str (Types.toString ty)),
                                  ("start", int (#start sp)), ("stop", int (#stop sp))]
    | NONE => Null

  fun answer (options : string list, method : string, params : json) : json =
    case method of
      "initialize" => Obj [("name", Str "rune"), ("version", Str Config.version),
                           ("methods", Arr (List.map Str ["diagnostics", "hover", "shutdown"]))]
    | "diagnostics" => (check (options, params); diagnostics ())
    | "hover" =>
        (check (options, params);
         case (field (params, "path"), field (params, "offset")) of
           (Str p, Num off) => hover (p, valOf (Int.fromString off) handle Option => raise Bad "an offset")
         | _ => raise Bad "hover wants a path and an offset")
    | m => raise Bad ("no method " ^ m)

  fun reply (id : json, result : json) = print (show (Obj [("jsonrpc", Str "2.0"), ("id", id), ("result", result)]) ^ "\n")
  fun failure (id : json, code : int, msg : string) =
    print (show (Obj [("jsonrpc", Str "2.0"), ("id", id), ("error", Obj [("code", int code), ("message", Str msg)])]) ^ "\n")

  (* a request answered by a child of its own *)
  fun request (options : string list, line : string) : bool =
    let
      val msg = parse line handle Bad why => (failure (Null, ~32700, "not JSON: " ^ why); Obj [])
      val id = field (msg, "id")
      val method = case field (msg, "method") of Str m => m | _ => ""
    in
      if method = "" then (if msg = Obj [] then () else failure (id, ~32600, "no method"); true)
      else if method = "shutdown" then (reply (id, Null); false)
      else if not (List.exists (fn m => m = method) ["initialize", "diagnostics", "hover"])
      then (failure (id, ~32601, "no method " ^ method); true)
      else
        (TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr;
         case Posix.Process.fork () of
           NONE =>
             (reply (id, answer (options, method, field (msg, "params")))
              handle Bad why => failure (id, ~32602, why)
                   | e => failure (id, ~32603, "the compiler failed: " ^ exnMessage e);
              TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr;
              Posix.Process.exit 0w0)
         | SOME pid =>
             (case Posix.Process.waitpid (Posix.Process.W_CHILD pid, []) of
                (_, Posix.Process.W_EXITED) => ()
              | _ => failure (id, ~32603, "the compiler ended without an answer"));
         true)
    end

  fun serve (options : string list) : OS.Process.status =
    let
      fun loop () =
        case TextIO.inputLine TextIO.stdIn of
          NONE => OS.Process.success
        | SOME l =>
            let val l = String.translate (fn #"\r" => "" | #"\n" => "" | c => String.str c) l
            in if String.size l = 0 then loop () else if request (options, l) then (TextIO.flushOut TextIO.stdOut; loop ())
               else OS.Process.success
            end
    in loop () end

  (* the entry point: --serve, else the compiler *)
  fun main (name : string, args : string list) : OS.Process.status =
    if List.exists (fn a => a = "--serve") args then serve (List.filter (fn a => a <> "--serve") args)
    else Main.main (name, args)
end
