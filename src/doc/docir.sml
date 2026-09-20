(* The intermediate representation of the documentation generator: what was
   extracted from the sources, before any output format is chosen
   (docs/plans/docgen.md, D9). Extraction fills it, the later passes resolve
   what it names, and a renderer reads nothing else. `dump` is its stable text
   form, which the tests of tests/doc compare. *)
structure DocIR =
struct
  (* A comment as it stands in the source, without its delimiters. *)
  type comment = {text : string, span : Source.span}
  type doc = comment list

  datatype kind = Val | Type | Eqtype | Datatype | Exception | Structure | Include | Sharing

  fun kindName k =
    case k of
      Val => "val" | Type => "type" | Eqtype => "eqtype" | Datatype => "datatype"
    | Exception => "exception" | Structure => "structure" | Include => "include" | Sharing => "sharing"

  (* A field of a record type that a specification writes out. *)
  type field = {label : string, ty : string, doc : doc}

  (* A constructor of a datatype specification. *)
  type con = {name : string, arg : string option, fields : field list, doc : doc}

  (* One thing a signature specifies. spec is its source text without
     comments, beginning with its keyword also where the source has `and`.
     sigref names the signature of `structure S : SIG` and of `include SIG`;
     body holds the specifications of `structure S : sig ... end`. *)
  datatype entry = Entry of
    {kind : kind, name : string, spec : string, span : Source.span,
     cons : con list, fields : field list,
     sigref : string option, body : item list option, doc : doc}

  (* A signature body in source order. *)
  and item = Item of entry

  datatype rhs =
      Body                          (* struct ... end *)
    | Alias of string               (* another structure *)
    | Apply of string * string      (* a functor and the text of its argument *)
    | Other

  type ascription = {sigexp : string, opaque : bool}

  datatype module =
      Signature of {name : string, file : string, span : Source.span, doc : doc,
                    source : string,            (* the declaration without comments *)
                    sigexp : string option,     (* when it is not sig ... end *)
                    body : item list}
    | Struct of {name : string, file : string, span : Source.span, doc : doc,
                 ascription : ascription option, rhs : rhs, subs : module list}
    | Functor of {name : string, file : string, span : Source.span, doc : doc,
                  param : string, result : ascription option}

  (* ---- the text form ---- *)
  fun indent n = CharVector.tabulate (2 * n, fn _ => #" ")

  (* Text that may have several lines: each after a `|`, so that the blanks
     at the start of a line are part of it. *)
  fun textLines (n, label, s) =
    case String.fields (fn c => c = #"\n") s of
      [l] => [indent n ^ label ^ ": " ^ l]
    | ls => (indent n ^ label ^ ":") :: List.map (fn l => indent (n + 1) ^ "|" ^ l) ls

  fun docLines (n, doc : doc) =
    List.concat (List.map (fn {text, ...} : comment => textLines (n, "doc", text)) doc)

  fun fieldLines n ({label, ty, doc} : field) =
    (indent n ^ "field " ^ label ^ " : " ^ ty) :: docLines (n + 1, doc)

  fun conLines n ({name, arg, fields, doc} : con) =
    (indent n ^ "con " ^ name ^ (case arg of SOME t => " of " ^ t | NONE => ""))
    :: docLines (n + 1, doc) @ List.concat (List.map (fieldLines (n + 1)) fields)

  fun entryLines n (Entry {kind, name, spec, cons, fields, sigref, body, doc, ...}) =
    (indent n ^ kindName kind ^ (if name = "" then "" else " " ^ name))
    :: textLines (n + 1, "spec", spec)
    @ (case sigref of SOME s => [indent (n + 1) ^ "signature: " ^ s] | NONE => [])
    @ docLines (n + 1, doc)
    @ List.concat (List.map (conLines (n + 1)) cons)
    @ List.concat (List.map (fieldLines (n + 1)) fields)
    @ (case body of SOME items => List.concat (List.map (itemLines (n + 1)) items) | NONE => [])

  and itemLines n (Item e) = entryLines n e

  fun ascriptionLines n (a : ascription option) =
    case a of
      SOME {sigexp, opaque} => textLines (n, if opaque then "sealed with" else "ascribed", sigexp)
    | NONE => []

  fun moduleLines n m =
    case m of
      Signature {name, doc, source, sigexp, body, ...} =>
        (indent n ^ "signature " ^ name)
        :: (case sigexp of SOME s => textLines (n + 1, "is", s) | NONE => [])
        @ docLines (n + 1, doc)
        @ List.concat (List.map (itemLines (n + 1)) body)
        @ textLines (n + 1, "source", source)
    | Struct {name, doc, ascription, rhs, subs, ...} =>
        (indent n ^ "structure " ^ name)
        :: ascriptionLines (n + 1) ascription
        @ (case rhs of
             Body => []
           | Alias s => [indent (n + 1) ^ "alias of: " ^ s]
           | Apply (f, arg) => textLines (n + 1, "application of " ^ f ^ " to", arg)
           | Other => [indent (n + 1) ^ "other"])
        @ docLines (n + 1, doc)
        @ List.concat (List.map (moduleLines (n + 1)) subs)
    | Functor {name, doc, param, result, ...} =>
        (indent n ^ "functor " ^ name)
        :: textLines (n + 1, "parameter", param)
        @ ascriptionLines (n + 1) result
        @ docLines (n + 1, doc)

  fun dump (file : string, modules : module list) : string =
    String.concat (List.map (fn l => l ^ "\n")
                            (("file " ^ file) :: List.concat (List.map (moduleLines 1) modules)))
end
