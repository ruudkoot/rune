(* What a piece of code in a comment refers to (docs/plans/docgen.md, D3). A
   code span that is one identifier, long or short, is a reference. It is
   looked up from the inside out: the arguments that the usage head names,
   the members of the signature being documented (from the substructure the
   comment stands in outwards, and through what the signature includes), the
   modules of the library. A member of a structure leads to the page of the
   structure's signature, so that `List.map` lands on LIST. This resolution is
   by name; it goes through the elaborated environments from M8 on. *)
structure DocResolve =
struct
  structure I = DocIR

  (* Where a reference leads: a page, and an anchor on it or "". *)
  type target = {page : string, anchor : string}

  (* signatures: by name. structures: the signature each public structure has
     (from its ascription; from its `Implements:` claim from M7 on).
     functors: the names of the documented functors. pageOf: the page of a
     signature, relative to the root of the output. *)
  type index = {signatures : I.module StringMap.map,
                structures : string StringMap.map,
                functors : unit StringMap.map,
                (* a name of the top-level environment that is a member of a
                   structure: `Subscript` is General.Subscript, `map` List.map *)
                tops : target StringMap.map}

  fun sigPage (name : string) : string = "sig/" ^ name ^ ".md"
  fun funPage (name : string) : string = "fun/" ^ name ^ ".md"

  (* The identifier that a piece of code is, if it is just that. *)
  fun identifier (c : string) : (string list * string) option =
    let
      val toks = Lexer.tokenize (Source.fromString ("<reference>", c))
    in
      if Vector.length toks <> 2 then NONE
      else
        case #1 (Vector.sub (toks, 0)) of
          Token.ID x => SOME ([], x)
        | Token.LONGID (path, x) => SOME (path, x)
        | _ => NONE
    end
    handle Error.CompileError _ => NONE

  fun bodyOf (index : index, sigName : string) : I.item list =
    case StringMap.find (#signatures index, sigName) of
      SOME (I.Signature {body, ...}) => body
    | _ => []

  (* The member `name` of a body: a value before a constructor before an
     exception before a type before a substructure, as prose mostly means
     them. `seen` stops a cycle of includes. *)
  fun member (index : index, page : string, items : I.item list, name : string, seen : string list) : target option =
    let
      fun entries () = List.mapPartial (fn I.Item (I.Entry e) => SOME e | _ => NONE) items
      fun entryOf kinds =
        List.find (fn e => #name e = name andalso List.exists (fn k => k = #kind e) kinds) (entries ())
      fun anchorOf (e : I.entryRecord) =
        SOME {page = page, anchor = DocAnchor.anchor {bound = I.BEntry (#kind e), path = #path e, name = #name e}}
      fun con () =
        List.foldl (fn (e, found) =>
                      case found of
                        SOME _ => found
                      | NONE =>
                          if List.exists (fn c : I.con => #name c = name) (#cons e)
                          then SOME {page = page, anchor = DocAnchor.anchor {bound = I.BCon, path = #path e, name = name}}
                          else NONE)
                   NONE (entries ())
      fun included () =
        List.foldl (fn (e, found) =>
                      case (found, #kind e, #sigref e, #body e) of
                        (SOME _, _, _, _) => found
                      | (NONE, I.Include, SOME s, _) =>
                          if List.exists (fn s' => s' = s) seen then NONE
                          else member (index, sigPage s, bodyOf (index, s), name, s :: seen)
                      | (NONE, I.Include, NONE, SOME inner) => member (index, page, inner, name, seen)
                      | _ => NONE)
                   NONE (entries ())
      fun first fs = case fs of [] => NONE | f :: rest => (case f () of SOME t => SOME t | NONE => first rest)
    in
      first [fn () => Option.mapPartial anchorOf (entryOf [I.Val]),
             con,
             fn () => Option.mapPartial anchorOf (entryOf [I.Exception]),
             fn () => Option.mapPartial anchorOf (entryOf [I.Type, I.Eqtype, I.Datatype]),
             fn () => Option.mapPartial anchorOf (entryOf [I.Structure]),
             included]
    end

  (* The member path.name of a body: the path leads through substructures,
     into their own signature where they name one. *)
  fun memberAt (index : index, page : string, items : I.item list, path : string list, name : string) : target option =
    case path of
      [] => member (index, page, items, name, [])
    | s :: rest =>
        let
          val sub = List.find (fn I.Item (I.Entry e) => #kind e = I.Structure andalso #name e = s | _ => false) items
        in
          case sub of
            SOME (I.Item (I.Entry {body = SOME inner, ...})) => memberAt (index, page, inner, rest, name)
          | SOME (I.Item (I.Entry {sigref = SOME s', ...})) => memberAt (index, sigPage s', bodyOf (index, s'), rest, name)
          | _ => NONE
        end

  (* The items of the substructure at `path` of a body, if it is written out
     there. *)
  fun inner (items : I.item list, path : string list) : I.item list option =
    case path of
      [] => SOME items
    | s :: rest =>
        (case List.find (fn I.Item (I.Entry e) => #kind e = I.Structure andalso #name e = s | _ => false) items of
           SOME (I.Item (I.Entry {body = SOME b, ...})) => inner (b, rest)
         | _ => NONE)

  fun member' (index, page, items, name) = member (index, page, items, name, [])

  datatype result =
      Target of target
    | Argument                      (* a name of the usage head *)
    | Unknown                       (* an unqualified name that is nothing we know: plain code *)
    | Unresolved                    (* a qualified name that leads nowhere: worth a warning *)
    | NotAReference

  (* code, in the comment of something at `path` of signature `sigName`
     ("" outside a signature), whose usage heads name `args`. *)
  fun resolve (index : index, sigName : string, path : string list, args : string list) (c : string) : result =
    case identifier c of
      NONE => NotAReference
    | SOME ([], x) =>
        if List.exists (fn a => a = x) args then Argument
        else
          let
            val body = bodyOf (index, sigName)
            (* from the innermost substructure outwards *)
            fun outwards p =
              case Option.mapPartial (fn items => member (index, sigPage sigName, items, x, [])) (inner (body, p)) of
                SOME t => SOME t
              | NONE => if List.null p then NONE else outwards (List.take (p, List.length p - 1))
          in
            case (if sigName = "" then NONE else outwards path) of
              SOME t => Target t
            | NONE =>
                if StringMap.member (#signatures index, x) then Target {page = sigPage x, anchor = ""}
                else if StringMap.member (#functors index, x) then Target {page = funPage x, anchor = ""}
                else
                  case StringMap.find (#structures index, x) of
                    SOME s => Target {page = sigPage s, anchor = ""}
                  | NONE =>
                      (case StringMap.find (#tops index, x) of
                         SOME t => Target t
                       | NONE => Unknown)
          end
    | SOME (head :: rest, x) =>
        let
          val viaSignature =
            if StringMap.member (#signatures index, head)
            then memberAt (index, sigPage head, bodyOf (index, head), rest, x) else NONE
          val viaStructure =
            case StringMap.find (#structures index, head) of
              SOME s => memberAt (index, sigPage s, bodyOf (index, s), rest, x)
            | NONE => NONE
          val viaSubstructure =
            if sigName = "" then NONE else memberAt (index, sigPage sigName, bodyOf (index, sigName), head :: rest, x)
        in
          case (viaSignature, viaStructure, viaSubstructure) of
            (SOME t, _, _) => Target t
          | (_, SOME t, _) => Target t
          | (_, _, SOME t) => Target t
          | _ => Unresolved
        end

  (* The signature that a signature expression names: its first identifier. *)
  fun sigexpHead (sigexp : string) : string option =
    case String.tokens (fn c => not (Char.isAlphaNum c orelse c = #"_" orelse c = #"'")) sigexp of
      s :: _ => SOME s
    | [] => NONE

  fun emptyIndex () : index =
    {signatures = StringMap.empty, structures = StringMap.empty, functors = StringMap.empty, tops = StringMap.empty}

  (* The index of some modules: every signature, every structure with the
     signature it claims first, every public functor. *)
  fun indexOf (modules : I.module list, claims : DocClaims.claim list, isPublic : string -> bool) : index =
    let
      val signatures =
        List.foldl (fn (m as I.Signature {name, ...}, acc) => StringMap.insert (acc, name, m) | (_, acc) => acc)
                   StringMap.empty modules
      val structures =
        List.foldl (fn (c : DocClaims.claim, acc) =>
                      if #isFunctor c orelse StringMap.member (acc, #name c) orelse not (StringMap.member (signatures, #signat c))
                      then acc else StringMap.insert (acc, #name c, #signat c))
                   StringMap.empty claims
      val functors =
        List.foldl (fn (I.Functor {name, ...}, acc) => if isPublic name then StringMap.insert (acc, name, ()) else acc
                     | (_, acc) => acc)
                   StringMap.empty modules
      val partial = {signatures = signatures, structures = structures, functors = functors, tops = StringMap.empty}
      (* the first structure that declares a member to be an unqualified name
         gives that name its description *)
      val tops =
        List.foldl (fn (I.Struct {name, twins, ...}, acc) =>
                        (case StringMap.find (structures, name) of
                           SOME s =>
                             List.foldl (fn ((member, other), acc) =>
                                           if CharVector.exists (fn c => c = #".") other orelse StringMap.member (acc, other) then acc
                                           else
                                             case member' (partial, sigPage s, bodyOf (partial, s), member) of
                                               SOME t => StringMap.insert (acc, other, t)
                                             | NONE => acc)
                                        acc twins
                         | NONE => acc)
                     | (_, acc) => acc)
                   StringMap.empty modules
    in
      {signatures = signatures, structures = structures, functors = functors, tops = tops}
    end
end
