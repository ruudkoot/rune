(* The anchors of a generated page (docs/plans/docgen.md, D8). GitHub makes
   the anchors of headings itself, and they are useless for SML: lowercased,
   punctuation dropped, so that `@` has none and `toString` collides with
   `tostring`. A page therefore carries explicit anchors, <a name="...">, of
   the form kind-name: the kind is one of type, con, fld, exn, val and str,
   the name is lowercased (GitHub lowercases what it looks for), a prime is
   spelled -prime and a symbolic identifier is spelled out: val-op-at,
   con-op-colon-colon. A member of a substructure has the path before its
   name: val-kind.file. Two anchors of a page must differ; the generator
   checks that, and never renumbers, so links from elsewhere stay good. *)
structure DocAnchor =
struct
  structure I = DocIR

  val symbols =
    [(#"!", "bang"), (#"%", "percent"), (#"&", "amp"), (#"$", "dollar"), (#"#", "hash"), (#"+", "plus"),
     (#"-", "minus"), (#"/", "slash"), (#":", "colon"), (#"<", "lt"), (#"=", "eq"), (#">", "gt"),
     (#"?", "question"), (#"@", "at"), (#"\\", "backslash"), (#"~", "tilde"), (#"`", "backquote"),
     (#"^", "caret"), (#"|", "bar"), (#"*", "star")]

  fun symbolName (c : char) : string =
    case List.find (fn (c', _) => c' = c) symbols of
      SOME (_, n) => n
    | NONE => "x" ^ Int.toString (Char.ord c)

  fun isSymbolic (name : string) : bool =
    name <> "" andalso not (Char.isAlpha (String.sub (name, 0)))

  fun spell (name : string) : string =
    if isSymbolic name then "op-" ^ String.concatWith "-" (List.map symbolName (String.explode name))
    else String.translate (fn #"'" => "-prime" | c => String.str (Char.toLower c)) name

  fun kindPrefix (bound : I.bound) : string =
    case bound of
      I.BCon => "con"
    | I.BField => "fld"
    | I.BEntry k =>
        (case k of
           I.Val => "val" | I.Type => "type" | I.Eqtype => "type" | I.Datatype => "type"
         | I.Exception => "exn" | I.Structure => "str" | I.Include => "include" | I.Sharing => "sharing")

  fun anchor ({bound, path, name} : I.binding) : string =
    kindPrefix bound ^ "-" ^ String.concatWith "." (List.map spell (path @ [name]))

  (* The table of conventions.md. *)
  fun symbolTable () : (string * string) list =
    List.map (fn (c, n) => (String.str c, n)) symbols
end
