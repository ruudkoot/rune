(* The colours of what is typed at the REPL (docs/plans/repl.md, D13): the
   compiler's own lexer, in the mode that never raises (Lexer.scan), a line
   at a time, and the names coloured by what they are in the session -- a
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

  (* the pieces of a line with their roles, the line's offsets *)
  fun rolesOf (env : Env.env, line : string, pieces : (int * int * Lexer.class) list) : (int * int * string) list =
    List.foldr
      (fn ((a, b, Lexer.Name), acc) => (a, b, roleIn (env, String.substring (line, a, b - a))) :: acc
        | ((a, b, Lexer.LongName), acc) =>
            let
              val parts = String.fields (fn c => c = #".") (String.substring (line, a, b - a))
              val path = List.take (parts, List.length parts - 1)
              val last = List.last parts
              val dot = b - String.size last
            in
              (a, dot, "syn.module")
              :: (dot, b, case structureAt (env, path) of SOME e => roleIn (e, last) | NONE => "syn.ident")
              :: acc
            end
        | ((a, b, c), acc) => (a, b, roleOf c) :: acc)
      [] pieces

  (* ---- the lines seen, by their text and the state they begin in ---- *)

  fun stateKey (s : Lexer.state) : string =
    case s of Lexer.Code => "c" | Lexer.InComment d => "C" ^ Int.toString d | Lexer.InGap => "g"

  val lines : ((int * int * string) list * Lexer.state) StringMap.map ref = ref StringMap.empty

  (* forgets the lines: the names in them may be others now *)
  fun reset () = lines := StringMap.empty

  fun lineAt (env : Env.env, line : string, state : Lexer.state) : (int * int * string) list * Lexer.state =
    let val key = stateKey state ^ "\n" ^ line
    in
      case StringMap.find (!lines, key) of
        SOME r => r
      | NONE =>
          let
            val (pieces, after) = Lexer.scan (line, state)
            val r = (rolesOf (env, line, pieces), after)
          in
            (* a bound on what is kept: a session types far fewer lines *)
            if StringMap.numItems (!lines) > 20000 then lines := StringMap.empty else ();
            lines := StringMap.insert (!lines, key, r);
            r
          end
    end

  (* The styles of the text's byte ranges, for the editor (LineEdit's
     highlight) *)
  fun highlight (env : Env.env) (text : string) : (int * int * Style.style) list =
    case !theme of
      NONE => []
    | SOME _ =>
        let
          val n = String.size text
          (* line by line, from offset i in the state the line before left *)
          fun go (i, state, acc) =
            if i > n then List.concat (List.rev acc)
            else
              let
                fun eol j = if j < n andalso String.sub (text, j) <> #"\n" then eol (j + 1) else j
                val j = eol i
                val (roles, after) = lineAt (env, String.substring (text, i, j - i), state)
                val styled = List.mapPartial (fn (a, b, role) =>
                                                let val st = styleOf role
                                                in if st = Style.plain then NONE else SOME (i + a, i + b, st) end) roles
              in go (j + 1, after, styled :: acc) end
        in go (0, Lexer.Code, []) end
end
