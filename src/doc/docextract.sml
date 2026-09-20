(* From a parsed source file to DocIR: the signatures with what they specify,
   in source order, and the structures and functors with what they are
   ascribed or bound to, each with the comments that document it. The
   specifications are taken from the syntax tree and shown as the source has
   them (DocSource.slice), because the tree has lost parentheses and layout and
   the elaborator expands abbreviations.

   A file is walked twice. The first walk only notes where everything that can
   be documented begins and ends; DocComments.attach then decides what each
   comment belongs to, and the second walk builds the modules with their
   comments in place. *)
structure DocExtract =
struct
  structure I = DocIR
  structure S = DocSource
  structure C = DocComments
  structure T = DocText

  type ctx = {src : S.t, table : C.table,
              texts : bool,                       (* false on the first walk, which needs no source text *)
              items : (int * int) list ref,       (* what can be documented *)
              regions : (int * int) list ref,     (* the bodies of the signatures *)
              tys : Ast.ty IntMap.map ref}        (* the types of the values, by where they begin *)

  (* What a comment documents decides which reserved paragraphs it may have. *)
  datatype place = Value | Entry | Part | SignatureDoc | StructureDoc | FunctorDoc | ProseDoc

  fun allowed (place : place, keyword : string) : bool =
    case keyword of
      "Raises" => place = Value
    | "Law" => place = Value
    | "Complexity" => place = Value
    | "Area" => place = SignatureDoc orelse place = FunctorDoc
    | "Status" => place = SignatureDoc orelse place = StructureDoc orelse place = FunctorDoc
    | "Implements" => place = StructureDoc orelse place = FunctorDoc
    | _ => true

  fun placeName (place : place) : string =
    case place of
      Value => "a value" | Entry => "this specification" | Part => "a constructor or a field"
    | SignatureDoc => "a signature" | StructureDoc => "a structure" | FunctorDoc => "a functor" | ProseDoc => "prose"

  (* The blocks of a comment, with the complaints about them. *)
  fun blocksOf (ctx : ctx, place : place, {start, stop, text} : C.comment) : T.block list =
    let
      val span = {file = S.name (#src ctx), start = start, stop = stop}
      val blocks = T.parse (fn why => DocDiag.error (span, why)) text
      fun check (prev, bs) =
        case bs of
          [] => ()
        | (b as T.Reserved (r as {keyword, ...})) :: rest =>
            ((case T.malformed r of SOME why => DocDiag.error (span, why) | NONE => ());
             if allowed (place, keyword) then ()
             else DocDiag.error (span, "`" ^ keyword ^ ":` does not belong in the comment of " ^ placeName place);
             if keyword = "Pinned by"
                andalso not (case prev of SOME (T.Reserved {keyword = k, ...}) => T.isNote k | _ => false)
             then DocDiag.error (span, "`Pinned by:` follows the note it pins directly")
             else ();
             check (SOME b, rest))
        | b :: rest => check (SOME b, rest)
    in
      check (NONE, blocks); blocks
    end

  fun margin (ctx : ctx, span : Source.span) : string = if #texts ctx then S.sliceAtMargin (#src ctx, span) else ""

  fun spanEq (a : Source.span, b : Source.span) = #start a = #start b andalso #stop a = #stop b

  (* The documentation of the item at [start, stop); the item is noted. *)
  fun docAt (ctx : ctx, place : place, start : int, stop : int) : I.doc =
    (#items ctx := (start, stop) :: !(#items ctx);
     List.concat (List.map (fn c => blocksOf (ctx, place, c)) (C.docsOf (#table ctx, start))))

  fun docOf (ctx : ctx, place : place, {start, stop, ...} : Source.span) : I.doc = docAt (ctx, place, start, stop)

  (* The first record type that a type writes out, outermost and leftmost. *)
  fun recordOf (ty : Ast.ty) : (string * Ast.ty) list option =
    case ty of
      Ast.TyRecord (fields, _) => SOME fields
    | Ast.TyVar _ => NONE
    | Ast.TyTuple (tys, _) => firstOf tys
    | Ast.TyCon (tys, _, _) => firstOf tys
    | Ast.TyArrow (a, b, _) => firstOf [a, b]
  and firstOf tys =
    case tys of
      [] => NONE
    | t :: rest => (case recordOf t of SOME r => SOME r | NONE => firstOf rest)

  fun tyText (ctx : ctx, ty) = if #texts ctx then S.oneLine (S.sliceSpan (#src ctx, Ast.spanOfTy ty)) else ""

  (* A field begins at its label: the tree has no span for it, but it is the
     token before the colon before the field's type (which may begin with
     parentheses that its span leaves out). *)
  fun labelStart (src : S.t, tyStart : int) : int =
    let
      fun back i = if i > 0 andalso S.token (src, i - 1) = Token.LPAREN then back (i - 1) else i
      val i = back (S.indexAt (src, tyStart))
    in
      if i >= 2 andalso S.token (src, i - 1) = Token.COLON then S.tokenStart (src, i - 2) else tyStart
    end

  fun fieldsOf (ctx : ctx, ty : Ast.ty option) : I.field list =
    case Option.mapPartial recordOf ty of
      NONE => []
    | SOME fields =>
        List.map (fn (label, t) =>
                    let val {start, stop, ...} = Ast.spanOfTy t
                    in {label = label, ty = tyText (ctx, t), doc = docAt (ctx, Part, labelStart (#src ctx, start), stop)} end)
                 fields

  fun conOf ctx (name, ty : Ast.ty option, span : Source.span) : I.con =
    let val doc = docOf (ctx, Part, span)
    in
      {name = name, arg = Option.map (fn t => tyText (ctx, t)) ty,
       fields = (case ty of SOME (Ast.TyRecord _) => fieldsOf (ctx, ty) | _ => []), doc = doc}
    end

  fun sigHead (e : Ast.sigexp) : string option =
    case e of
      Ast.SigId (n, _) => SOME n
    | Ast.SigWhere (e', _, _) => sigHead e'
    | Ast.SigSig _ => NONE

  (* An entry follows the one before it closely: between the token that ends
     the one and the first token of the other (its keyword, or `and`) there is
     no comment and no blank line. *)
  fun adjacent (src : S.t, start : int) : bool =
    let
      fun back i = if i > 0 andalso C.isPrefix (S.token (src, i - 1)) then back (i - 1) else i
      val i = back (S.indexAt (src, start))
    in
      i > 0 andalso S.token (src, i - 1) <> Token.SIG
      andalso List.null (S.commentsBefore (src, i))
      andalso C.newlines (src, S.tokenStop (src, i - 1), S.tokenStart (src, i)) < 2
    end

  fun entry (ctx : ctx) {kind, name, spec, span, cons, fields, sigref, body} : I.item =
    I.Item (I.Entry {kind = kind, name = name, spec = spec, span = span, cons = cons, fields = fields,
                     sigref = sigref, body = body, adjacent = #texts ctx andalso adjacent (#src ctx, #start span),
                     heads = [], leader = NONE,
                     doc = docOf (ctx, if kind = I.Val then Value else Entry, span)})

  (* ---- usage heads and groups ---- *)
  fun firstParagraphCode (doc : I.doc) : string list =
    case doc of
      T.Para is :: _ => List.mapPartial (fn T.Code c => SOME c | _ => NONE) is
    | _ => []

  (* The heads of the values of a body. A value with a comment gets its own
     head from it; the values that follow it closely and have no comment are
     documented with it when its first paragraph has a head for them. Every
     head is checked against the type of its value. *)
  fun withHeads (ctx : ctx, items : I.item list) : I.item list =
    let
      fun headFor (name, span : Source.span, cands) =
        case List.find (fn (h : DocHead.head, _) => #name h = name) cands of
          NONE => []
        | SOME (h, args) =>
            ((case IntMap.find (!(#tys ctx), #start span) of
                SOME ty =>
                  (case DocHead.mismatch (ty, args) of
                     SOME why => DocDiag.error (span, "the usage `" ^ #code h ^ "` does not fit the type of " ^ name ^ ": " ^ why)
                   | NONE => ())
              | NONE => ());
             [h])
      fun go (items, leader) =
        case items of
          [] => []
        | I.Item (I.Entry (e as {kind = I.Val, ...})) :: rest =>
            let
              val {kind, name, spec, span, cons, fields, sigref, body, adjacent, doc, ...} = e
              fun rebuilt (heads, l) =
                I.Item (I.Entry {kind = kind, name = name, spec = spec, span = span, cons = cons, fields = fields,
                                 sigref = sigref, body = body, adjacent = adjacent, heads = heads, leader = l, doc = doc})
            in
              if not (List.null doc) then
                let val cands = DocHead.headsOf (firstParagraphCode doc)
                in rebuilt (headFor (name, span, cands), NONE) :: go (rest, SOME (name, cands)) end
              else
                case leader of
                  SOME (lname, cands) =>
                    (case (adjacent, headFor (name, span, cands)) of
                       (true, heads as _ :: _) => rebuilt (heads, SOME lname) :: go (rest, leader)
                     | _ => I.Item (I.Entry e) :: go (rest, NONE))
                | NONE => I.Item (I.Entry e) :: go (rest, NONE)
            end
        | item :: rest => item :: go (rest, NONE)
    in
      if #texts ctx then go (items, NONE) else items
    end

  (* keyword and the description at span, e.g. "val" and `null : 'a list -> bool` *)
  fun described (ctx : ctx, keyword, span) = keyword ^ " " ^ margin (ctx, span)

  fun itemStart (item : I.item, otherwise : int) : int =
    case item of I.Item (I.Entry {span, ...}) => #start span | _ => otherwise

  (* The entries of a body with its headings and prose between them, by
     position. The bodies inside it have taken theirs already. *)
  fun withStandalone (ctx : ctx, entries : I.item list, {start, stop, ...} : Source.span) : I.item list =
    let
      val src = #src ctx
      fun toItem (c : C.comment) =
        if C.isHeading c then I.Section (C.headingTitle c)
        else I.Prose (blocksOf (ctx, ProseDoc, c))
      fun merge (es, []) = es
        | merge ([], cs) = List.map toItem cs
        | merge (e :: es, c :: cs) =
            if #start c < itemStart (e, 0) then toItem c :: merge (e :: es, cs) else e :: merge (es, c :: cs)
    in
      #regions ctx := (start, stop) :: !(#regions ctx);
      merge (entries, C.takeStandalone (#table ctx, start, stop))
    end

  fun specItems (ctx : ctx) (spec : Ast.spec) : I.item list =
    let
      val src = #src ctx
      val entry = entry ctx
    in
      case spec of
        Ast.SpecVal (descs, _) =>
          List.map (fn (name, ty, sp) =>
                      (#tys ctx := IntMap.insert (!(#tys ctx), #start sp, ty);
                       entry {kind = I.Val, name = name, spec = described (ctx, "val", sp), span = sp, cons = [],
                              fields = fieldsOf (ctx, SOME ty), sigref = NONE, body = NONE})) descs
      | Ast.SpecType (descs, _) =>
          List.map (fn (_, name, sp) =>
                      entry {kind = I.Type, name = name, spec = described (ctx, "type", sp), span = sp, cons = [],
                             fields = [], sigref = NONE, body = NONE}) descs
      | Ast.SpecEqtype (descs, _) =>
          List.map (fn (_, name, sp) =>
                      entry {kind = I.Eqtype, name = name, spec = described (ctx, "eqtype", sp), span = sp, cons = [],
                             fields = [], sigref = NONE, body = NONE}) descs
      | Ast.SpecDatatype (binds, _) =>
          List.map (fn {name, cons, span, ...} =>
                      entry {kind = I.Datatype, name = name, spec = described (ctx, "datatype", span), span = span,
                             cons = List.map (conOf ctx) cons, fields = [], sigref = NONE, body = NONE}) binds
      | Ast.SpecDatatypeRepl (name, _, sp) =>
          [entry {kind = I.Datatype, name = name, spec = margin (ctx, sp), span = sp, cons = [],
                  fields = [], sigref = NONE, body = NONE}]
      | Ast.SpecException (descs, _) =>
          List.map (fn (name, ty, sp) =>
                      entry {kind = I.Exception, name = name, spec = described (ctx, "exception", sp), span = sp,
                             cons = [], fields = fieldsOf (ctx, ty), sigref = NONE, body = NONE}) descs
      | Ast.SpecStructure (descs, _) =>
          List.map (fn (name, sigexp, sp) =>
                      case sigexp of
                        Ast.SigSig (specs, inner) =>
                          entry {kind = I.Structure, name = name, spec = "structure " ^ name ^ " : sig ... end", span = sp,
                                 cons = [], fields = [], sigref = NONE, body = SOME (body ctx (specs, inner))}
                      | _ =>
                          entry {kind = I.Structure, name = name, spec = described (ctx, "structure", sp), span = sp,
                                 cons = [], fields = [], sigref = sigHead sigexp, body = NONE}) descs
        (* `type t = ty` is parsed into its derived form, an include of a
           signature with a where clause; all its parts have the span of the
           description, which a written include never has. *)
      | Ast.SpecInclude (sigexp as Ast.SigWhere (Ast.SigSig ([Ast.SpecType ([(_, name, _)], _)], inner), wheres, _), sp) =>
          if spanEq (inner, sp) then
            [entry {kind = I.Type, name = name, spec = described (ctx, "type", sp), span = sp, cons = [],
                    fields = (case wheres of [(_, _, ty, _)] => fieldsOf (ctx, SOME ty) | _ => []),
                    sigref = NONE, body = NONE}]
          else includeItems ctx (sigexp, sp)
      | Ast.SpecInclude (sigexp, sp) => includeItems ctx (sigexp, sp)
      | Ast.SpecSharingType (_, sp) =>
          [entry {kind = I.Sharing, name = "", spec = margin (ctx, sp), span = sp, cons = [], fields = [],
                  sigref = NONE, body = NONE}]
      | Ast.SpecSharing (_, sp) =>
          [entry {kind = I.Sharing, name = "", spec = margin (ctx, sp), span = sp, cons = [], fields = [],
                  sigref = NONE, body = NONE}]
    end

  and includeItems ctx (sigexp : Ast.sigexp, sp : Source.span) : I.item list =
    let
      val src = #src ctx
      val entry = entry ctx
    in
      case sigHead sigexp of
        SOME n =>
          [entry {kind = I.Include, name = n, spec = described (ctx, "include", Ast.spanOfSigexp sigexp), span = sp,
                  cons = [], fields = [], sigref = SOME n, body = NONE}]
      | NONE =>
          (case sigexp of
             Ast.SigSig (specs, inner) =>
               [entry {kind = I.Include, name = "", spec = "include sig ... end", span = sp, cons = [], fields = [],
                       sigref = NONE, body = SOME (body ctx (specs, inner))}]
           | _ =>
               [entry {kind = I.Include, name = "", spec = described (ctx, "include", Ast.spanOfSigexp sigexp), span = sp,
                       cons = [], fields = [], sigref = NONE, body = NONE}])
    end

  and body ctx (specs : Ast.spec list, span : Source.span) : I.item list =
    withStandalone (ctx, withHeads (ctx, List.concat (List.map (specItems ctx) specs)), span)

  (* A binding shown whole: from the keyword before it when its span begins
     after that, as the span of `signature S = ...` does at S. *)
  fun fromKeyword (src, keyword : Token.token, span as {file, start, stop} : Source.span) : Source.span =
    let val i = S.indexAt (src, start)
    in
      if i > 0 andalso S.token (src, i - 1) = keyword then {file = file, start = S.tokenStart (src, i - 1), stop = stop}
      else span
    end

  fun ascriptionOf (ctx : ctx) (e : Ast.strexp) : I.ascription option * Ast.strexp =
    case e of
      Ast.StrAscribe (e', sigexp, opaque, _) =>
        (SOME {sigexp = margin (ctx, Ast.spanOfSigexp sigexp), opaque = opaque}, e')
    | _ => (NONE, e)

  fun structOf (ctx : ctx) ({name, strexp, span} : Ast.strbind) : I.module =
    let
      val src = #src ctx
      val doc = docOf (ctx, StructureDoc, span)
      val (ascription, e) = ascriptionOf ctx strexp
      val (rhs, subs) =
        case e of
          Ast.StrStruct (decs, _) => (I.Body, List.concat (List.map (subStructs ctx) decs))
        | Ast.StrId (longid, _) => (I.Alias (Ast.longidToString longid), [])
        | Ast.StrApp (f, arg, _, _) => (I.Apply (f, margin (ctx, Ast.spanOfStrexp arg)), [])
        | _ => (I.Other, [])
    in
      I.Struct {name = name, file = S.name src, span = span, doc = doc, ascription = ascription, rhs = rhs, subs = subs}
    end

  and subStructs ctx (dec : Ast.dec) : I.module list =
    case dec of
      Ast.DStructure (binds, _) => List.map (structOf ctx) binds
    | _ => []

  fun modulesOf (ctx : ctx) (dec : Ast.dec) : I.module list =
    let val src = #src ctx
    in
      case dec of
        Ast.DSignature (binds, _) =>
          List.map (fn {name, sigexp, span} =>
                      let val doc = docOf (ctx, SignatureDoc, span)
                      in
                        I.Signature {name = name, file = S.name src, span = span, doc = doc,
                                     source = margin (ctx, fromKeyword (src, Token.SIGNATURE, span)),
                                     sigexp = (case sigexp of
                                                 Ast.SigSig _ => NONE
                                               | _ => SOME (margin (ctx, Ast.spanOfSigexp sigexp))),
                                     body = (case sigexp of
                                               Ast.SigSig (specs, inner) => body ctx (specs, inner)
                                             | _ => [])}
                      end) binds
      | Ast.DStructure (binds, _) => List.map (structOf ctx) binds
      | Ast.DFunctor (binds, _) =>
          List.map (fn {name, param, paramSig, body, span} =>
                      I.Functor {name = name, file = S.name src, span = span, doc = docOf (ctx, FunctorDoc, span),
                                 param = (case param of
                                            SOME x => x ^ " : " ^ margin (ctx, Ast.spanOfSigexp paramSig)
                                          | NONE => margin (ctx, Ast.spanOfSigexp paramSig)),
                                 result = #1 (ascriptionOf ctx body)}) binds
      | _ => []
    end

  (* The modules a file declares. Every file is parsed on its own, with the
     fixity of the top level. *)
  fun file (path : string) : I.module list =
    let
      val src = S.load path
      val (prog, _) = Parser.parseTokensWith (#toks src, Fixity.initial)
      fun walk (table, texts) =
        let val ctx = {src = src, table = table, texts = texts, items = ref [], regions = ref [], tys = ref IntMap.empty}
        in (List.concat (List.map (modulesOf ctx) prog), ctx) end
      val (_, first) = walk (C.empty, false)
      val (modules, _) = walk (C.attach (src, !(#items first), !(#regions first)), true)
    in
      modules
    end
end
