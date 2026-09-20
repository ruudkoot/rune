(* From a parsed source file to DocIR: the signatures with what they specify,
   in source order, and the structures and functors with what they are
   ascribed or bound to. The specifications are taken from the syntax tree and
   shown as the source has them (DocSource.slice), because the tree has lost
   parentheses and layout and the elaborator expands abbreviations. *)
structure DocExtract =
struct
  structure I = DocIR
  structure S = DocSource

  fun spanEq (a : Source.span, b : Source.span) = #start a = #start b andalso #stop a = #stop b

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

  fun tyText (src, ty) = S.oneLine (S.sliceSpan (src, Ast.spanOfTy ty))

  fun fieldsOf (src, ty : Ast.ty option) : I.field list =
    case Option.mapPartial recordOf ty of
      NONE => []
    | SOME fields => List.map (fn (label, t) => {label = label, ty = tyText (src, t), doc = []}) fields

  fun conOf src (name, ty : Ast.ty option, _ : Source.span) : I.con =
    {name = name, arg = Option.map (fn t => tyText (src, t)) ty,
     fields = (case ty of SOME (Ast.TyRecord _) => fieldsOf (src, ty) | _ => []), doc = []}

  fun sigHead (e : Ast.sigexp) : string option =
    case e of
      Ast.SigId (n, _) => SOME n
    | Ast.SigWhere (e', _, _) => sigHead e'
    | Ast.SigSig _ => NONE

  fun entry {kind, name, spec, span, cons, fields, sigref, body} : I.item =
    I.Item (I.Entry {kind = kind, name = name, spec = spec, span = span, cons = cons, fields = fields,
                     sigref = sigref, body = body, doc = []})

  (* keyword and the description at span, e.g. "val" and `null : 'a list -> bool` *)
  fun described (src, keyword, span) = keyword ^ " " ^ S.sliceAtMargin (src, span)

  fun specItems (src : S.t) (spec : Ast.spec) : I.item list =
    case spec of
      Ast.SpecVal (descs, _) =>
        List.map (fn (name, ty, sp) =>
                    entry {kind = I.Val, name = name, spec = described (src, "val", sp), span = sp, cons = [],
                           fields = fieldsOf (src, SOME ty), sigref = NONE, body = NONE}) descs
    | Ast.SpecType (descs, _) =>
        List.map (fn (_, name, sp) =>
                    entry {kind = I.Type, name = name, spec = described (src, "type", sp), span = sp, cons = [],
                           fields = [], sigref = NONE, body = NONE}) descs
    | Ast.SpecEqtype (descs, _) =>
        List.map (fn (_, name, sp) =>
                    entry {kind = I.Eqtype, name = name, spec = described (src, "eqtype", sp), span = sp, cons = [],
                           fields = [], sigref = NONE, body = NONE}) descs
    | Ast.SpecDatatype (binds, _) =>
        List.map (fn {name, cons, span, ...} =>
                    entry {kind = I.Datatype, name = name, spec = described (src, "datatype", span), span = span,
                           cons = List.map (conOf src) cons, fields = [], sigref = NONE, body = NONE}) binds
    | Ast.SpecDatatypeRepl (name, _, sp) =>
        [entry {kind = I.Datatype, name = name, spec = S.sliceAtMargin (src, sp), span = sp, cons = [],
                fields = [], sigref = NONE, body = NONE}]
    | Ast.SpecException (descs, _) =>
        List.map (fn (name, ty, sp) =>
                    entry {kind = I.Exception, name = name, spec = described (src, "exception", sp), span = sp,
                           cons = [], fields = fieldsOf (src, ty), sigref = NONE, body = NONE}) descs
    | Ast.SpecStructure (descs, _) =>
        List.map (fn (name, sigexp, sp) =>
                    case sigexp of
                      Ast.SigSig (specs, _) =>
                        entry {kind = I.Structure, name = name, spec = "structure " ^ name ^ " : sig ... end", span = sp,
                               cons = [], fields = [], sigref = NONE,
                               body = SOME (List.concat (List.map (specItems src) specs))}
                    | _ =>
                        entry {kind = I.Structure, name = name, spec = described (src, "structure", sp), span = sp,
                               cons = [], fields = [], sigref = sigHead sigexp, body = NONE}) descs
      (* `type t = ty` is parsed into its derived form, an include of a
         signature with a where clause; all its parts have the span of the
         description, which a written include never has. *)
    | Ast.SpecInclude (sigexp as Ast.SigWhere (Ast.SigSig ([Ast.SpecType ([(_, name, _)], _)], inner), wheres, _), sp) =>
        if spanEq (inner, sp) then
          [entry {kind = I.Type, name = name, spec = described (src, "type", sp), span = sp, cons = [],
                  fields = (case wheres of [(_, _, ty, _)] => fieldsOf (src, SOME ty) | _ => []),
                  sigref = NONE, body = NONE}]
        else includeItems src (sigexp, sp)
    | Ast.SpecInclude (sigexp, sp) => includeItems src (sigexp, sp)
    | Ast.SpecSharingType (_, sp) =>
        [entry {kind = I.Sharing, name = "", spec = S.sliceAtMargin (src, sp), span = sp, cons = [], fields = [],
                sigref = NONE, body = NONE}]
    | Ast.SpecSharing (_, sp) =>
        [entry {kind = I.Sharing, name = "", spec = S.sliceAtMargin (src, sp), span = sp, cons = [], fields = [],
                sigref = NONE, body = NONE}]

  and includeItems src (sigexp : Ast.sigexp, sp : Source.span) : I.item list =
    case sigHead sigexp of
      SOME n =>
        [entry {kind = I.Include, name = n, spec = described (src, "include", Ast.spanOfSigexp sigexp), span = sp,
                cons = [], fields = [], sigref = SOME n, body = NONE}]
    | NONE =>
        (case sigexp of
           Ast.SigSig (specs, _) =>
             [entry {kind = I.Include, name = "", spec = "include sig ... end", span = sp, cons = [], fields = [],
                     sigref = NONE, body = SOME (List.concat (List.map (specItems src) specs))}]
         | _ =>
             [entry {kind = I.Include, name = "", spec = described (src, "include", Ast.spanOfSigexp sigexp), span = sp,
                     cons = [], fields = [], sigref = NONE, body = NONE}])

  (* A binding shown whole: from the keyword before it when its span begins
     after that, as the span of `signature S = ...` does at S. *)
  fun fromKeyword (src, keyword : Token.token, span as {file, start, stop} : Source.span) : Source.span =
    let val i = S.indexAt (src, start)
    in
      if i > 0 andalso S.token (src, i - 1) = keyword then {file = file, start = S.tokenStart (src, i - 1), stop = stop}
      else span
    end

  fun ascriptionOf src (e : Ast.strexp) : I.ascription option * Ast.strexp =
    case e of
      Ast.StrAscribe (e', sigexp, opaque, _) =>
        (SOME {sigexp = S.sliceAtMargin (src, Ast.spanOfSigexp sigexp), opaque = opaque}, e')
    | _ => (NONE, e)

  fun structOf src ({name, strexp, span} : Ast.strbind) : I.module =
    let
      val (ascription, e) = ascriptionOf src strexp
      val (rhs, subs) =
        case e of
          Ast.StrStruct (decs, _) => (I.Body, List.concat (List.map (subStructs src) decs))
        | Ast.StrId (longid, _) => (I.Alias (Ast.longidToString longid), [])
        | Ast.StrApp (f, arg, _, _) => (I.Apply (f, S.sliceAtMargin (src, Ast.spanOfStrexp arg)), [])
        | _ => (I.Other, [])
    in
      I.Struct {name = name, file = S.name src, span = span, doc = [], ascription = ascription, rhs = rhs, subs = subs}
    end

  and subStructs src (dec : Ast.dec) : I.module list =
    case dec of
      Ast.DStructure (binds, _) => List.map (structOf src) binds
    | _ => []

  fun modulesOf (src : S.t) (dec : Ast.dec) : I.module list =
    case dec of
      Ast.DSignature (binds, _) =>
        List.map (fn {name, sigexp, span} =>
                    I.Signature {name = name, file = S.name src, span = span, doc = [],
                                 source = S.sliceAtMargin (src, fromKeyword (src, Token.SIGNATURE, span)),
                                 sigexp = (case sigexp of
                                             Ast.SigSig _ => NONE
                                           | _ => SOME (S.sliceAtMargin (src, Ast.spanOfSigexp sigexp))),
                                 body = (case sigexp of
                                           Ast.SigSig (specs, _) => List.concat (List.map (specItems src) specs)
                                         | _ => [])}) binds
    | Ast.DStructure (binds, _) => List.map (structOf src) binds
    | Ast.DFunctor (binds, _) =>
        List.map (fn {name, param, paramSig, body, span} =>
                    I.Functor {name = name, file = S.name src, span = span, doc = [],
                               param = (case param of
                                          SOME x => x ^ " : " ^ S.sliceAtMargin (src, Ast.spanOfSigexp paramSig)
                                        | NONE => S.sliceAtMargin (src, Ast.spanOfSigexp paramSig)),
                               result = #1 (ascriptionOf src body)}) binds
    | _ => []

  (* The modules a file declares. Every file is parsed on its own, with the
     fixity of the top level. *)
  fun file (path : string) : I.module list =
    let
      val src = S.load path
      val (prog, _) = Parser.parseTokensWith (#toks src, Fixity.initial)
    in
      List.concat (List.map (modulesOf src) prog)
    end
end
