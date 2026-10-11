(* The colours of SML at the REPL (docs/plans/repl.md, D13), what is typed
   and what the REPL says alike -- an echo's keyword and type, :type,
   :info, :browse, :search: the compiler's own lexer, in the mode that never
   raises (Lexer.scan), a line at a time, and the names coloured by where
   they stand -- in a type, among a datatype's constructors, at a
   structure's name -- and elsewhere by what they are in the session -- a
   constructor, a type, a structure -- looked up in its environment without
   counting as a use of it (the cache's usages are the compiles').

   The editor asks for the colours of the whole text at each key. A line's
   pieces depend only on its text and on the state the line before it
   left (in a comment, in a string's gap), so they are kept by both, and a
   key re-lexes the line it changed and those after it whose state it
   changed: a long entry costs a lookup a line. What the names are is the
   session's, so `reset` forgets every line once an entry has run. *)
structure ReplHighlight =
struct
  (* the theme of the REPL's output, NONE for no colours (ReplFront) *)
  val theme : Color.theme option ref = ref NONE

  val styles : Style.style StringMap.map ref = ref StringMap.empty

  (* the editor's style of a role of the palette *)
  fun styleOf (role : string) : Style.style =
    case !theme of
      NONE => Style.plain
    | SOME t =>
        case StringMap.find (!styles, role) of
          SOME s => s
        | NONE =>
            let val s = Style.parameters (Color.style (t, role))
            in styles := StringMap.insert (!styles, role, s); s end

  (* ---- what a name is in the session ---- *)

  fun structureAt (env : Env.env, path : string list) : Env.env option =
    case path of
      [] => SOME env
    | p :: rest => (case StringMap.find (Env.strs env, p) of SOME e => structureAt (e, rest) | NONE => NONE)

  fun roleIn (env : Env.env, name : string) : string =
    case StringMap.find (Env.vals env, name) of
      SOME (Env.Con _) => "syn.constructor"
    | SOME (Env.Exn _) => "syn.constructor"
    | SOME _ => "syn.ident"
    | NONE =>
        if StringMap.member (Env.tys env, name) then "syn.type"
        else if StringMap.member (Env.strs env, name) then "syn.module"
        else "syn.ident"

  fun roleOf (class : Lexer.class) : string =
    case class of
      Lexer.Keyword => "syn.keyword"
    | Lexer.Operator => "syn.operator"
    | Lexer.TyVar => "syn.tyvar"
    | Lexer.Number => "syn.number"
    | Lexer.Text => "syn.string"
    | Lexer.Comment => "syn.comment"
    | Lexer.Bad => "syn.error"
    | _ => "syn.punct"

  (* ---- where a piece stands ---- *)

  (* In code, a name is what the session makes it; in a type -- after a
     `:`, a type's `=`, a constructor's `of` -- a name is a type, but for a
     record's label, until the depth of brackets the type began at closes,
     or a `,` of that depth, a `=`, a `=>`, a `|`, a `;` or a keyword ends
     it, back to code or, from a datatype's `of`, to its constructors; after
     `type`, `datatype` and the like, a type's name; after a datatype's `=`
     and its `|`s, constructors; after `exception`, a constructor; after
     `structure`, `signature`, `functor`, `open` or `include`, structures
     and signatures. Not a parser: what it gets wrong is a colour. *)
  datatype mode = Code | InType of int * bool | TypeHead of bool | Cons | ExnHead | ModHead

  (* the mode, the depth of brackets, and the keyword that began the
     declaration, which an `and` goes on with *)
  type context = {mode : mode, depth : int, decl : string}

  val code : context = {mode = Code, depth = 0, decl = ""}
  (* a type by itself: an echo's, :type's *)
  val aType : context = {mode = InType (0, false), depth = 0, decl = ""}

  fun contextKey ({mode, depth, decl} : context) : string =
    (case mode of
       Code => "c"
     | InType (d, c) => "t" ^ Int.toString d ^ (if c then "c" else "")
     | TypeHead b => if b then "D" else "T"
     | Cons => "K"
     | ExnHead => "E"
     | ModHead => "M") ^ "," ^ Int.toString depth ^ "," ^ decl

  fun afterKeyword (k : string, ctx as {mode, depth, decl} : context) : context =
    let
      fun begins (d, m) = {mode = m, depth = depth, decl = d}
      fun declaration k =
        case k of
          "type" => SOME (TypeHead false)
        | "eqtype" => SOME (TypeHead false)
        | "withtype" => SOME (TypeHead false)
        | "datatype" => SOME (TypeHead true)
        | "abstype" => SOME (TypeHead true)
        | "exception" => SOME ExnHead
        | "structure" => SOME ModHead
        | "signature" => SOME ModHead
        | "functor" => SOME ModHead
        | "open" => SOME ModHead
        | "include" => SOME ModHead
        | _ => NONE
    in
      case (k, declaration k) of
        (_, SOME m) => begins (k, m)
      | ("and", NONE) => (case declaration decl of SOME m => begins (decl, m) | NONE => begins (decl, Code))
      | ("of", NONE) =>
          (case mode of
             Cons => begins (decl, InType (depth, true))
           | ExnHead => begins (decl, InType (depth, false))
           | _ => ctx)
      | _ => begins (if k = "val" orelse k = "fun" then k else decl, Code)
    end

  fun afterSymbol (s : string, ctx as {mode, depth, decl} : context) : context =
    let
      fun to m = {mode = m, depth = depth, decl = decl}
      val opens = s = "(" orelse s = "{" orelse String.isSuffix "[" s
    in
      if opens then {mode = mode, depth = depth + 1, decl = decl}
      else
        case s of
          ")" => closed ctx
        | "]" => closed ctx
        | "}" => closed ctx
        | ":" => (case mode of Code => to (InType (depth, false)) | _ => ctx)
        | ":>" => to ModHead
        | "=" =>
            (case mode of
               TypeHead false => to (InType (depth, false))
             | TypeHead true => to Cons
             | InType _ => to Code
             | ModHead => to Code
             | ExnHead => to Code
             | _ => ctx)
        | "=>" => (case mode of InType _ => to Code | _ => ctx)
        | ";" => to Code
        | "|" => (case mode of InType (_, true) => to Cons | InType _ => to Code | _ => ctx)
        | "," => (case mode of InType (d, _) => if depth = d then to Code else ctx | _ => ctx)
        | _ => ctx
    end
  and closed {mode, depth, decl} =
    case mode of
      InType (d, _) => if depth - 1 < d then {mode = Code, depth = depth - 1, decl = decl}
                       else {mode = mode, depth = depth - 1, decl = decl}
    | _ => {mode = mode, depth = depth - 1, decl = decl}

  (* a name's role where it stands; a label is a name before a `:` *)
  fun nameRole (env : Env.env, mode : mode, name : string, label : bool) : string =
    case mode of
      Code => roleIn (env, name)
    | InType _ => if label then "syn.ident" else "syn.type"
    | TypeHead _ => "syn.type"
    | Cons => "syn.constructor"
    | ExnHead => "syn.constructor"
    | ModHead => "syn.module"

  (* the pieces of a line with their roles, the line's offsets, from the
     context the line begins in, and the context it leaves; in what the
     REPL says (said), `con` at a line's start is the word :info writes
     for a constructor *)
  fun rolesOf (env : Env.env, line : string, pieces : (int * int * Lexer.class) list, ctx : context, said : bool)
      : (int * int * string) list * context =
    let
      fun text (a, b) = String.substring (line, a, b - a)
      fun beforeColon rest =
        case List.filter (fn (_, _, c) => c <> Lexer.Comment) rest of
          (a, b, _) :: _ => text (a, b) = ":"
        | [] => false
      fun go ([], ctx, _, acc) = (List.rev acc, ctx)
        | go ((a, b, class) :: rest, ctx : context, first, acc) =
            case class of
              Lexer.Name =>
                let val n = text (a, b)
                in
                  if said andalso first andalso n = "con" then go (rest, ctx, false, (a, b, "syn.keyword") :: acc)
                  else go (rest, ctx, false, (a, b, nameRole (env, #mode ctx, n, beforeColon rest)) :: acc)
                end
            | Lexer.LongName =>
                let
                  val parts = String.fields (fn c => c = #".") (text (a, b))
                  val path = List.take (parts, List.length parts - 1)
                  val last = List.last parts
                  val dot = b - String.size last
                  val role =
                    case #mode ctx of
                      Code => (case structureAt (env, path) of SOME e => roleIn (e, last) | NONE => "syn.ident")
                    | m => nameRole (env, m, last, false)
                in go (rest, ctx, false, (dot, b, role) :: (a, dot, "syn.module") :: acc) end
            | Lexer.Keyword => go (rest, afterKeyword (text (a, b), ctx), false, (a, b, "syn.keyword") :: acc)
            | Lexer.Operator =>
                let
                  val s = text (a, b)
                  val role =
                    case (#mode ctx, StringMap.find (Env.vals env, s)) of
                      (Code, SOME (Env.Con _)) => "syn.constructor"
                    | (Code, SOME (Env.Exn _)) => "syn.constructor"
                    | _ => "syn.operator"
                in go (rest, afterSymbol (s, ctx), false, (a, b, role) :: acc) end
            | Lexer.Other => go (rest, afterSymbol (text (a, b), ctx), false, (a, b, "syn.punct") :: acc)
            | Lexer.Comment => go (rest, ctx, first, (a, b, "syn.comment") :: acc)
            | c => go (rest, ctx, false, (a, b, roleOf c) :: acc)
    in go (pieces, ctx, true, []) end

  (* ---- the lines seen, by their text and the state they begin in ---- *)

  fun stateKey (s : Lexer.state) : string =
    case s of Lexer.Code => "c" | Lexer.InComment d => "C" ^ Int.toString d | Lexer.InGap => "g"

  val lines : ((int * int * string) list * (Lexer.state * context)) StringMap.map ref = ref StringMap.empty

  (* forgets the lines: the names in them may be others now *)
  fun reset () = lines := StringMap.empty

  fun lineAt (env : Env.env, line : string, (state, ctx) : Lexer.state * context)
      : (int * int * string) list * (Lexer.state * context) =
    let val key = stateKey state ^ ";" ^ contextKey ctx ^ "\n" ^ line
    in
      case StringMap.find (!lines, key) of
        SOME r => r
      | NONE =>
          let
            val (pieces, after) = Lexer.scan (line, state)
            val (roles, ctx') = rolesOf (env, line, pieces, ctx, false)
            val r = (roles, (after, ctx'))
          in
            (* a bound on what is kept: a session types far fewer lines *)
            if StringMap.numItems (!lines) > 20000 then lines := StringMap.empty else ();
            lines := StringMap.insert (!lines, key, r);
            r
          end
    end

  (* whether a text ends inside a comment: not where it opens none, else by
     its lines' states, which highlight has kept *)
  fun endsInComment (env : Env.env, text : string) : bool =
    String.isSubstring "(*" text andalso
    let
      val n = String.size text
      fun go (i, start) =
        let
          fun eol j = if j < n andalso String.sub (text, j) <> #"\n" then eol (j + 1) else j
          val j = eol i
          val (_, after as (state, _)) = lineAt (env, String.substring (text, i, j - i), start)
        in
          if j >= n then (case state of Lexer.InComment _ => true | _ => false) else go (j + 1, after)
        end
    in go (0, (Lexer.Code, code)) end

  (* the roles of a text's byte ranges, line by line from a state and a
     context: typed (each line looked up in what is kept) or said *)
  fun rolesIn (line : string * (Lexer.state * context) -> (int * int * string) list * (Lexer.state * context))
              (text : string, start : Lexer.state * context) : (int * int * string) list =
    let
      val n = String.size text
      fun go (i, state, acc) =
        if i > n then List.concat (List.rev acc)
        else
          let
            fun eol j = if j < n andalso String.sub (text, j) <> #"\n" then eol (j + 1) else j
            val j = eol i
            val (roles, after) = line (String.substring (text, i, j - i), state)
          in go (j + 1, after, List.map (fn (a, b, r) => (i + a, i + b, r)) roles :: acc) end
    in go (0, start, []) end

  (* what the REPL says of a text of SML, from a context, and the roles of
     its pieces; what the lexer refuses is not marked in it *)
  fun said (env : Env.env, text : string, ctx : context) : (int * int * string) list =
    List.filter (fn (_, _, r) => r <> "syn.error")
                (rolesIn (fn (l, (state, c)) =>
                            let
                              val (pieces, after) = Lexer.scan (l, state)
                              val (roles, c') = rolesOf (env, l, pieces, c, true)
                            in (roles, (after, c')) end)
                         (text, (Lexer.Code, ctx)))

  (* that text in the palette's styles, where there are colours *)
  fun paint (env : Env.env, text : string, ctx : context) : string =
    case !theme of
      NONE => text
    | SOME t =>
        let
          fun go (i, [], acc) = String.concat (List.rev (String.extract (text, i, NONE) :: acc))
            | go (i, (a, b, role) :: rest, acc) =
                go (b, rest, Color.paintIn t role (String.substring (text, a, b - a))
                             :: String.substring (text, i, a - i) :: acc)
        in go (0, said (env, text, ctx), []) end

  (* that text as a document of its pieces in their roles, for a document
     the REPL lays out (an echo's type) *)
  fun doc (env : Env.env, text : string, ctx : context) : string Pretty.doc =
    let
      fun go (i, [], acc) = Pretty.concat (List.rev (Pretty.text (String.extract (text, i, NONE)) :: acc))
        | go (i, (a, b, role) :: rest, acc) =
            go (b, rest, Pretty.annotate (role, Pretty.text (String.substring (text, a, b - a)))
                         :: Pretty.text (String.substring (text, i, a - i)) :: acc)
    in go (0, said (env, text, ctx), []) end

  (* The styles of the text's byte ranges, for the editor (LineEdit's
     highlight) *)
  fun highlight (env : Env.env) (text : string) : (int * int * Style.style) list =
    case !theme of
      NONE => []
    | SOME _ =>
        let
          (* a command (`:` and a letter at the start): its name as a
             keyword, what follows it as code *)
          val command =
            if String.size text > 1 andalso String.sub (text, 0) = #":" andalso Char.isAlpha (String.sub (text, 1))
            then SOME (CharVector.findi (fn (_, c) => Char.isSpace c) text)
            else NONE
          val roles =
            case command of
              NONE => rolesIn (fn (l, start) => lineAt (env, l, start)) (text, (Lexer.Code, code))
            | SOME found =>
                let
                  val k = case found of SOME (k, _) => k | NONE => String.size text
                  (* :browse's argument is a structure's or a signature's name *)
                  val ctx = if String.isPrefix ":b" text then {mode = ModHead, depth = 0, decl = ""} else code
                in
                  (0, k, "syn.keyword")
                  :: List.map (fn (a, b, r) => (k + a, k + b, r))
                              (rolesIn (fn (l, start) => lineAt (env, l, start)) (String.extract (text, k, NONE),
                                                                                   (Lexer.Code, ctx)))
                end
        in
          List.mapPartial (fn (a, b, role) => let val st = styleOf role in if st = Style.plain then NONE else SOME (a, b, st) end)
                          roles
        end
end
