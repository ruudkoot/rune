(* Abstract syntax. Nodes carry mutable annotation slots that elaboration
   fills in (resolved identifier status, record types) for the translator,
   and each an id of its own (linting roadmap, D1). *)
structure Ast =
struct
  type span = Source.span
  type longid = string list * string          (* structure path, name *)

  (* A node's identity: every node of the syntax has one, the last of its
     constructor's fields, given by the parser in the order it makes nodes
     (a node after its parts) and fresh in each copy of a tree
     (SyntaxAst.copy), so that no two nodes of a session share one. What
     the elaborator records of a node (Witness) is keyed by it, and dropped
     with the unit or declaration that recorded it (UnitBasis.undo,
     Elaborate.restore). noId is
     no node's: a node the compiler makes of others for its own use. *)
  type id = int
  val noId = ~1
  val nextId = ref 0
  val () = CompilerState.cellRoot ("Ast.nextId", nextId)
  fun freshId () : id = let val n = !nextId in nextId := n + 1; n end

  fun longidToString (path, name) = String.concatWith "." (path @ [name])

  datatype scon =
      SInt of IntInf.int
    | SWord of IntInf.int
    | SReal of string
    | SString of string           (* a constant whose characters fit 8 bits *)
    | SWideString of int list * int option
                                  (* one with a code point above 255, or with
                                     a raw character above 127 read under
                                     --unicode: SOME its first (Token) *)
    | SChar of int * int option   (* the code point of a character constant,
                                     SOME it where it is raw *)

  (* The constants of a type registered with _overload (Overload.literal). *)
  datatype ovliteral = OvBits of int | OvVia of string list * string

  (* Resolved status of a value identifier, filled by elaboration, with the
     type of this use of it: the instance of its scheme (docs/ir.md). *)
  datatype varinfo =
      VLocal of int * Types.ty                  (* variable stamp *)
    | VGlobal of int * Types.ty                 (* top-level variable stamp *)
    | VCon of coninfo * Types.ty
    | VExn of exninfo * Types.ty
    | VBuiltin of string * Types.ty             (* builtin operator (possibly overloaded) and its operand type *)
    | VConVal of coninfo * Types.ty             (* constructor that lost its status through a signature *)
    | VExnVal of exninfo * Types.ty             (* exception constructor that lost its status *)

  and patinfo =
      PIVar of int * bool                       (* stamp, isGlobal *)
    | PICon of coninfo
    | PIExn of exninfo

  withtype coninfo = {name : string, tag : int, hasArg : bool, ncons : int, isRef : bool,
                      siblings : (string * bool) list}   (* all constructors of the datatype (name, has argument), by tag *)
       and exninfo = {name : string, stamp : int, isGlobal : bool, hasArg : bool, builtin : int option}

  (* where a dynamic structure comes from: the unit in a file, loaded when
     the declaration runs, or the module of the program that exports the
     name, a virtual module's implementation (docs/build.md) *)
  datatype dynamicFrom = DynamicFile of string | DynamicVirtual of string
  (* a dynamic module's record (D3): its values and exceptions, a slot each
     by name -- each a global, its type, and whether it is an exception's --
     then a record of its own for each substructure, by name, as a functor's
     records are *)
  datatype dynamicRecord = DynRecord of (int * Types.ty * bool) list * dynamicRecord list

  datatype exp =
      EScon of scon * Types.ty option ref * span * id   (* the type of an int or word constant, filled by elaboration *)
    | EVar of longid * varinfo option ref * span * id
    | ERecord of (string * exp * span) list * span * id   (* each field with its label's span *)
    | ETuple of exp list * span * id   (* including () *)
    | ESelect of string * Types.ty option ref * span * id   (* #lab *)
    | EList of exp list * Types.ty option ref * span * id   (* the type of the list, filled by elaboration *)
    | ESeq of exp list * span * id
    | ELet of dec list * exp * span * id
    | EApp of exp * exp * span * id
    | ETyped of exp * ty * span * id
    | EAndalso of exp * exp * span * id
    | EOrelse of exp * exp * span * id
    | EHandle of exp * mrule list * span * id
    | ERaise of exp * span * id
    | EIf of exp * exp * exp * span * id
    | EWhile of exp * exp * span * id
    | ECase of exp * mrule list * span * id
    | EFn of mrule list * Types.ty option ref * span * id   (* the type of the function, filled by elaboration *)
    | EPrim of string * ty * Types.ty option ref * span * id   (* _prim "name" : ty, and ty elaborated *)

  and pat =
      PWild of span * id
    | PScon of scon * Types.ty option ref * span * id
    | PVar of longid * patinfo option ref * span * id   (* variable or nullary constructor *)
    | PRecord of (string * pat * span) list * bool * Types.ty option ref * span * id
                                  (* fields with their labels' spans, flexible, full record type *)
    | PTuple of pat list * span * id
    | PList of pat list * span * id
    | PApp of longid * patinfo option ref * pat * span * id   (* constructor application *)
    | PTyped of pat * ty * span * id
    | PLayered of string * ty option * pat * patinfo option ref * span * id
    | POr of pat list * span * id   (* (p1 | ... | pn), with --or-patterns *)

  and ty =
      TyVar of string * span * id
    | TyRecord of (string * ty * span) list * span * id
    | TyTuple of ty list * span * id
    | TyCon of ty list * longid * span * id
    | TyArrow of ty * ty * span * id

  and dec =
      DVal of tyvarseq * (pat * exp) list * span * id
    | DValRec of tyvarseq * (pat * exp) list * span * id
    | DFun of tyvarseq * fundef list * span * id
    | DType of typbind list * span * id
    | DDatatype of datbind list * typbind list * span * id
    | DDatatypeRepl of string * longid * span * id
    | DAbstype of datbind list * typbind list * dec list * span * id
    | DException of exbind list * span * id
    | DLocal of dec list * dec list * span * id
    | DOpen of longid list * span * id
    | DInfix of int * string list * span * id
    | DInfixr of int * string list * span * id
    | DNonfix of string list * span * id
    | DOverload of {kind : string, strid : string list, literal : ovliteral, span : span, id : id}   (* _overload *)
    | DStructure of strbind list * span * id
    | DSignature of sigbind list * span * id
    | DFunctor of funbind list * span * id

  and strexp =
      StrStruct of dec list * span * id
    | StrId of longid * span * id
    | StrAscribe of strexp * sigexp * bool * span * id   (* true = opaque (:>) *)
    | StrApp of string * strexp * span * id   (* functor application *)
    | StrLet of dec list * strexp * span * id
    | StrDynamic of dynamicFrom * sigexp * dynamic option ref * span * id   (* _dynamic "path" : SIG, _virtual : SIG (docs/units.md, Dynamic modules) *)
    | StrExport of string * sigexp * strexp * dynamic option ref * span * id   (* _export structure X : SIG = strexp *)

  and sigexp =
      SigSig of spec list * span * id
    | SigId of string * span * id
    | SigWhere of sigexp * (string list * longid * ty * span) list * span * id   (* where type tyvarseq longtycon = ty *)

  and spec =
      SpecVal of (string * ty * span) list * span * id
    | SpecType of (string list * string * span) list * span * id
    | SpecEqtype of (string list * string * span) list * span * id
    | SpecDatatype of datbind list * span * id
    | SpecDatatypeRepl of string * longid * span * id
    | SpecException of (string * ty option * span) list * span * id
    | SpecStructure of (string * sigexp * span) list * span * id
    | SpecInclude of sigexp * span * id
    | SpecSharingType of longid list * span * id
    | SpecSharing of longid list * span * id   (* structure sharing (derived form) *)

  and exbind =
      ExnDecl of string * ty option * patinfo option ref * span * id
    | ExnRepl of string * longid * patinfo option ref * span * id

  (* a sequence of explicit type variables, each with its span *)
  withtype tyvarseq = (string * span) list
       (* a match rule: its span runs from its pattern's to its body's
          (spanOfRule) *)
       and mrule = pat * exp
       (* a clause of a fun: its span runs from its first token to its
          body's end *)
       and clause = {pats : pat list, resty : ty option, body : exp, span : span, id : id}
       and fundef = {name : string, clauses : {pats : pat list, resty : ty option, body : exp, span : span, id : id} list,
                     info : patinfo option ref, span : span, id : id}
       and typbind = {tyvars : (string * span) list, name : string, ty : ty, span : span, id : id}
       and datbind = {tyvars : (string * span) list, name : string, cons : (string * ty option * span) list, span : span,
                      id : id}
       and strbind = {name : string, strexp : strexp, span : span, id : id}
       and sigbind = {name : string, sigexp : sigexp, span : span, id : id}
       and funbind = {name : string, param : string option, paramSig : sigexp, body : strexp, span : span, id : id}
       (* what elaboration finds of a dynamic module's boundary: the
          fingerprint of the signature's ABI, its record of slots
          (dynamicRecord) and the global of RuneDynamic.load or
          RuneDynamic.export, and a global of the client's for the record *)
       and dynamic = {fingerprint : string, slots : dynamicRecord, via : int, temp : int, reloadable : bool}

  type program = dec list

  fun spanOfExp e =
    case e of
      EScon (_, _, s, _) => s | EVar (_, _, s, _) => s | ERecord (_, s, _) => s | ETuple (_, s, _) => s
    | ESelect (_, _, s, _) => s | EList (_, _, s, _) => s | ESeq (_, s, _) => s | ELet (_, _, s, _) => s
    | EApp (_, _, s, _) => s | ETyped (_, _, s, _) => s | EAndalso (_, _, s, _) => s
    | EOrelse (_, _, s, _) => s | EHandle (_, _, s, _) => s | ERaise (_, s, _) => s
    | EIf (_, _, _, s, _) => s | EWhile (_, _, s, _) => s | ECase (_, _, s, _) => s
    | EFn (_, _, s, _) => s | EPrim (_, _, _, s, _) => s

  fun spanOfPat p =
    case p of
      PWild (s, _) => s | PScon (_, _, s, _) => s | PVar (_, _, s, _) => s | PRecord (_, _, _, s, _) => s
    | PTuple (_, s, _) => s | PList (_, s, _) => s | PApp (_, _, _, s, _) => s | PTyped (_, _, s, _) => s
    | PLayered (_, _, _, _, s, _) => s | POr (_, s, _) => s

  (* The alternatives of a pattern: the patterns without or-patterns that it
     matches as, one for every choice of an alternative in each of its
     or-patterns, in order. A pattern without one is its only alternative;
     the alternatives share the annotation slots of the pattern, and the ids
     of its nodes. *)
  fun alternatives (p : pat) : pat list =
    let
      (* every choice of an element from each list, in order *)
      fun choices [] = [[]]
        | choices (xs :: rest) =
          let val tails = choices rest
          in List.concat (List.map (fn x => List.map (fn t => x :: t) tails) xs) end
    in
      case p of
        POr (ps, _, _) => List.concat (List.map alternatives ps)
      | PRecord (fields, flex, slot, sp, n) =>
          List.map (fn ps => PRecord (ListPair.map (fn ((l, _, lsp), q) => (l, q, lsp)) (fields, ps), flex, slot, sp, n))
                   (choices (List.map (alternatives o #2) fields))
      | PTuple (ps, sp, n) => List.map (fn ps => PTuple (ps, sp, n)) (choices (List.map alternatives ps))
      | PList (ps, sp, n) => List.map (fn ps => PList (ps, sp, n)) (choices (List.map alternatives ps))
      | PApp (id, slot, arg, sp, n) => List.map (fn a => PApp (id, slot, a, sp, n)) (alternatives arg)
      | PTyped (q, t, sp, n) => List.map (fn q => PTyped (q, t, sp, n)) (alternatives q)
      | PLayered (v, t, q, slot, sp, n) => List.map (fn q => PLayered (v, t, q, slot, sp, n)) (alternatives q)
      | _ => [p]
    end

  fun hasOr (p : pat) : bool =
    case p of
      POr _ => true
    | PRecord (fields, _, _, _, _) => List.exists (hasOr o #2) fields
    | PTuple (ps, _, _) => List.exists hasOr ps
    | PList (ps, _, _) => List.exists hasOr ps
    | PApp (_, _, arg, _, _) => hasOr arg
    | PTyped (q, _, _, _) => hasOr q
    | PLayered (_, _, q, _, _, _) => hasOr q
    | _ => false

  fun spanOfTy t =
    case t of
      TyVar (_, s, _) => s | TyRecord (_, s, _) => s | TyTuple (_, s, _) => s | TyCon (_, _, s, _) => s
    | TyArrow (_, _, s, _) => s

  fun spanOfDec d =
    case d of
      DVal (_, _, s, _) => s | DValRec (_, _, s, _) => s | DFun (_, _, s, _) => s | DType (_, s, _) => s
    | DDatatype (_, _, s, _) => s | DDatatypeRepl (_, _, s, _) => s | DAbstype (_, _, _, s, _) => s | DException (_, s, _) => s
    | DLocal (_, _, s, _) => s | DOpen (_, s, _) => s | DInfix (_, _, s, _) => s | DInfixr (_, _, s, _) => s
    | DNonfix (_, s, _) => s | DOverload {span = s, ...} => s | DStructure (_, s, _) => s | DSignature (_, s, _) => s | DFunctor (_, s, _) => s

  fun spanOfStrexp e =
    case e of
      StrStruct (_, s, _) => s | StrId (_, s, _) => s | StrAscribe (_, _, _, s, _) => s
    | StrApp (_, _, s, _) => s | StrLet (_, _, s, _) => s
    | StrDynamic (_, _, _, s, _) => s | StrExport (_, _, _, _, s, _) => s

  fun spanOfSigexp e =
    case e of
      SigSig (_, s, _) => s | SigId (_, s, _) => s | SigWhere (_, _, s, _) => s

  (* a record's fields without their labels' spans *)
  fun unlabel (fields : (string * 'a * span) list) : (string * 'a) list = List.map (fn (l, x, _) => (l, x)) fields

  (* a match rule's span: from its pattern's start to its body's end *)
  fun spanOfRule ((p, e) : mrule) : span =
    let val a = spanOfPat p and b = spanOfExp e
    in {file = #file a, start = #start a, stop = #stop b} end

  (* the span of a sequence of explicit type variables: from the first to
     the last, the parentheses left out; noSpan where there is none *)
  fun spanOfTyvars (vs : tyvarseq) : span =
    case vs of
      [] => Source.noSpan
    | (_, a) :: _ => {file = #file a, start = #start a, stop = #stop (#2 (List.last vs))}

  (* the id of each kind of node *)
  fun idOfExp e =
    case e of
      EScon (_, _, _, n) => n | EVar (_, _, _, n) => n | ERecord (_, _, n) => n | ETuple (_, _, n) => n
    | ESelect (_, _, _, n) => n | EList (_, _, _, n) => n | ESeq (_, _, n) => n | ELet (_, _, _, n) => n
    | EApp (_, _, _, n) => n | ETyped (_, _, _, n) => n | EAndalso (_, _, _, n) => n
    | EOrelse (_, _, _, n) => n | EHandle (_, _, _, n) => n | ERaise (_, _, n) => n
    | EIf (_, _, _, _, n) => n | EWhile (_, _, _, n) => n | ECase (_, _, _, n) => n
    | EFn (_, _, _, n) => n | EPrim (_, _, _, _, n) => n
  fun idOfPat p =
    case p of
      PWild (_, n) => n | PScon (_, _, _, n) => n | PVar (_, _, _, n) => n | PRecord (_, _, _, _, n) => n
    | PTuple (_, _, n) => n | PList (_, _, n) => n | PApp (_, _, _, _, n) => n | PTyped (_, _, _, n) => n
    | PLayered (_, _, _, _, _, n) => n | POr (_, _, n) => n
  fun idOfTy t =
    case t of
      TyVar (_, _, n) => n | TyRecord (_, _, n) => n | TyTuple (_, _, n) => n | TyCon (_, _, _, n) => n
    | TyArrow (_, _, _, n) => n
  fun idOfDec d =
    case d of
      DVal (_, _, _, n) => n | DValRec (_, _, _, n) => n | DFun (_, _, _, n) => n | DType (_, _, n) => n
    | DDatatype (_, _, _, n) => n | DDatatypeRepl (_, _, _, n) => n | DAbstype (_, _, _, _, n) => n
    | DException (_, _, n) => n | DLocal (_, _, _, n) => n | DOpen (_, _, n) => n | DInfix (_, _, _, n) => n
    | DInfixr (_, _, _, n) => n | DNonfix (_, _, n) => n | DOverload {id = n, ...} => n | DStructure (_, _, n) => n
    | DSignature (_, _, n) => n | DFunctor (_, _, n) => n
  fun idOfStrexp e =
    case e of
      StrStruct (_, _, n) => n | StrId (_, _, n) => n | StrAscribe (_, _, _, _, n) => n
    | StrApp (_, _, _, n) => n | StrLet (_, _, _, n) => n
    | StrDynamic (_, _, _, _, n) => n | StrExport (_, _, _, _, _, n) => n
  fun idOfSigexp e =
    case e of
      SigSig (_, _, n) => n | SigId (_, _, n) => n | SigWhere (_, _, _, n) => n

  (* The variables of a pattern allowed on the left of a recursive value
     binding (Section 2.9 restricts only the expression): variables, layered
     and typed patterns and wildcards. Returns the variables with their
     annotation slots and the type annotations met, or NONE otherwise. *)
  fun recBindVars (p : pat) : ((string * patinfo option ref * span) list * ty list) option =
    case p of
      PVar (([], name), slot, sp, _) => SOME ([(name, slot, sp)], [])
    | PWild (_, _) => SOME ([], [])
    | PTyped (p, t, _, _) => (case recBindVars p of SOME (vs, ts) => SOME (vs, t :: ts) | NONE => NONE)
    | PLayered (name, tyopt, p, slot, sp, _) =>
        (case recBindVars p of
           SOME (vs, ts) => SOME ((name, slot, sp) :: vs, (case tyopt of SOME t => [t] | NONE => []) @ ts)
         | NONE => NONE)
    | _ => NONE

    fun sconToString sc =
    case sc of
      SInt i => IntInf.toString i
    | SWord w => "0w" ^ IntInf.toString w
    | SReal r => r
    | SString s => "\"" ^ String.toString s ^ "\""
    | SWideString (s, _) => "\"" ^ Scon.text s ^ "\""
    | SChar (c, _) => "#\"" ^ Scon.escape c ^ "\""

  fun expToString e =
    case e of
      EScon (sc, _, _, _) => sconToString sc
    | EVar (id, _, _, _) => longidToString id
    | ERecord (fields, _, _) => "{" ^ String.concatWith ", " (List.map (fn (l, e, _) => l ^ " = " ^ expToString e) fields) ^ "}"
    | ETuple (es, _, _) => "(" ^ String.concatWith ", " (List.map expToString es) ^ ")"
    | ESelect (l, _, _, _) => "#" ^ l
    | EList (es, _, _, _) => "[" ^ String.concatWith ", " (List.map expToString es) ^ "]"
    | ESeq (es, _, _) => "(" ^ String.concatWith "; " (List.map expToString es) ^ ")"
    | ELet (ds, e, _, _) => "let " ^ String.concatWith " " (List.map decToString ds) ^ " in " ^ expToString e ^ " end"
    | EApp (f, a, _, _) => "(" ^ expToString f ^ " " ^ expToString a ^ ")"
    | ETyped (e, t, _, _) => "(" ^ expToString e ^ " : " ^ tyToString t ^ ")"
    | EAndalso (a, b, _, _) => "(" ^ expToString a ^ " andalso " ^ expToString b ^ ")"
    | EOrelse (a, b, _, _) => "(" ^ expToString a ^ " orelse " ^ expToString b ^ ")"
    | EHandle (e, m, _, _) => "(" ^ expToString e ^ " handle " ^ matchToString m ^ ")"
    | ERaise (e, _, _) => "(raise " ^ expToString e ^ ")"
    | EIf (a, b, c, _, _) => "(if " ^ expToString a ^ " then " ^ expToString b ^ " else " ^ expToString c ^ ")"
    | EWhile (a, b, _, _) => "(while " ^ expToString a ^ " do " ^ expToString b ^ ")"
    | ECase (e, m, _, _) => "(case " ^ expToString e ^ " of " ^ matchToString m ^ ")"
    | EFn (m, _, _, _) => "(fn " ^ matchToString m ^ ")"
    | EPrim (n, t, _, _, _) => "(_prim \"" ^ n ^ "\" : " ^ tyToString t ^ ")"

  and matchToString rules =
    String.concatWith " | " (List.map (fn (p, e) => patToString p ^ " => " ^ expToString e) rules)

  and patToString p =
    case p of
      PWild (_, _) => "_"
    | PScon (sc, _, _, _) => sconToString sc
    | PVar (id, _, _, _) => longidToString id
    | PRecord (fields, flex, _, _, _) =>
        "{" ^ String.concatWith ", " (List.map (fn (l, p, _) => l ^ " = " ^ patToString p) fields)
        ^ (if flex then ", ..." else "") ^ "}"
    | PTuple (ps, _, _) => "(" ^ String.concatWith ", " (List.map patToString ps) ^ ")"
    | PList (ps, _, _) => "[" ^ String.concatWith ", " (List.map patToString ps) ^ "]"
    | PApp (id, _, p, _, _) => "(" ^ longidToString id ^ " " ^ patToString p ^ ")"
    | PTyped (p, t, _, _) => "(" ^ patToString p ^ " : " ^ tyToString t ^ ")"
    | PLayered (v, NONE, p, _, _, _) => "(" ^ v ^ " as " ^ patToString p ^ ")"
    | PLayered (v, SOME t, p, _, _, _) => "(" ^ v ^ " : " ^ tyToString t ^ " as " ^ patToString p ^ ")"
    | POr (ps, _, _) => "(" ^ String.concatWith " | " (List.map patToString ps) ^ ")"

  and tyToString t =
    case t of
      TyVar (v, _, _) => v
    | TyRecord (fields, _, _) => "{" ^ String.concatWith ", " (List.map (fn (l, t, _) => l ^ " : " ^ tyToString t) fields) ^ "}"
    | TyTuple (ts, _, _) => "(" ^ String.concatWith " * " (List.map tyToString ts) ^ ")"
    | TyCon ([], id, _, _) => longidToString id
    | TyCon (ts, id, _, _) => "(" ^ String.concatWith ", " (List.map tyToString ts) ^ ") " ^ longidToString id
    | TyArrow (a, b, _, _) => "(" ^ tyToString a ^ " -> " ^ tyToString b ^ ")"

  and decToString d =
    let
      fun tyvars ([] : tyvarseq) = "" | tyvars vs = "(" ^ String.concatWith ", " (List.map #1 vs) ^ ") "
      fun binds bs = String.concatWith " and " (List.map (fn (p, e) => patToString p ^ " = " ^ expToString e) bs)
    in
      case d of
        DVal (tvs, bs, _, _) => "val " ^ tyvars tvs ^ binds bs
      | DValRec (tvs, bs, _, _) => "val " ^ tyvars tvs ^ "rec " ^ binds bs
      | DFun (tvs, fs, _, _) =>
          "fun " ^ tyvars tvs ^
          String.concatWith " and "
            (List.map (fn {name, clauses, ...} =>
                          String.concatWith " | "
                            (List.map (fn {pats, resty, body, ...} =>
                                          name ^ " " ^ String.concatWith " " (List.map patToString pats)
                                          ^ (case resty of NONE => "" | SOME t => " : " ^ tyToString t)
                                          ^ " = " ^ expToString body) clauses)) fs)
      | DType (tbs, _, _) =>
          "type " ^ String.concatWith " and " (List.map (fn {tyvars = tvs, name, ty, ...} => tyvars tvs ^ name ^ " = " ^ tyToString ty) tbs)
      | DDatatype (dbs, tbs, _, _) =>
          "datatype " ^
          String.concatWith " and "
            (List.map (fn {tyvars = tvs, name, cons, ...} =>
                          tyvars tvs ^ name ^ " = " ^
                          String.concatWith " | "
                            (List.map (fn (c, NONE, _) => c | (c, SOME t, _) => c ^ " of " ^ tyToString t) cons)) dbs)
          ^ (case tbs of [] => "" | _ => " withtype " ^ decToString (DType (tbs, Source.noSpan, noId)))
      | DDatatypeRepl (n, id, _, _) => "datatype " ^ n ^ " = datatype " ^ longidToString id
      | DAbstype (dbs, tbs, ds, _, _) =>
          "abs" ^ decToString (DDatatype (dbs, tbs, Source.noSpan, noId)) ^ " with "
          ^ String.concatWith " " (List.map decToString ds) ^ " end"
      | DException (ebs, _, _) =>
          "exception " ^
          String.concatWith " and "
            (List.map (fn ExnDecl (n, NONE, _, _, _) => n
                        | ExnDecl (n, SOME t, _, _, _) => n ^ " of " ^ tyToString t
                        | ExnRepl (n, id, _, _, _) => n ^ " = " ^ longidToString id) ebs)
      | DLocal (d1, d2, _, _) =>
          "local " ^ String.concatWith " " (List.map decToString d1) ^ " in "
          ^ String.concatWith " " (List.map decToString d2) ^ " end"
      | DOpen (ids, _, _) => "open " ^ String.concatWith " " (List.map longidToString ids)
      | DInfix (p, ids, _, _) => "infix " ^ Int.toString p ^ " " ^ String.concatWith " " ids
      | DInfixr (p, ids, _, _) => "infixr " ^ Int.toString p ^ " " ^ String.concatWith " " ids
      | DNonfix (ids, _, _) => "nonfix " ^ String.concatWith " " ids
      | DOverload {kind, strid, ...} => "_overload " ^ kind ^ " " ^ String.concatWith "." strid
      | DStructure (bs, _, _) =>
          "structure " ^ String.concatWith " and " (List.map (fn {name, strexp, ...} => name ^ " = " ^ strexpToString strexp) bs)
      | DSignature (bs, _, _) =>
          "signature " ^ String.concatWith " and " (List.map (fn {name, sigexp, ...} => name ^ " = " ^ sigexpToString sigexp) bs)
      | DFunctor (bs, _, _) =>
          "functor " ^
          String.concatWith " and "
            (List.map (fn {name, param, paramSig, body, ...} =>
                          name ^ " (" ^ (case param of SOME p => p ^ " : " ^ sigexpToString paramSig
                                                       | NONE => (case paramSig of SigSig (ss, _, _) => specsToString ss | _ => sigexpToString paramSig))
                          ^ ") = " ^ strexpToString body) bs)
    end

  and strexpToString e =
    case e of
      StrStruct (ds, _, _) => "struct " ^ String.concatWith " " (List.map decToString ds) ^ " end"
    | StrId (id, _, _) => longidToString id
    | StrAscribe (e, s, opaque, _, _) => strexpToString e ^ (if opaque then " :> " else " : ") ^ sigexpToString s
    | StrApp (f, a, _, _) => f ^ " (" ^ strexpToString a ^ ")"
    | StrLet (ds, e, _, _) => "let " ^ String.concatWith " " (List.map decToString ds) ^ " in " ^ strexpToString e ^ " end"
    | StrDynamic (DynamicFile path, s, _, _, _) => "_dynamic \"" ^ String.toString path ^ "\" : " ^ sigexpToString s
    | StrDynamic (DynamicVirtual _, s, _, _, _) => "_virtual : " ^ sigexpToString s
    | StrExport (_, s, e, _, _, _) => "_export " ^ sigexpToString s ^ " (" ^ strexpToString e ^ ")"

  and sigexpToString s =
    case s of
      SigSig (specs, _, _) => "sig " ^ specsToString specs ^ " end"
    | SigId (n, _, _) => n
    | SigWhere (s, clauses, _, _) =>
        sigexpToString s ^ " where " ^
        String.concatWith " and "
          (List.map (fn (tvs, id, t, _) => "type " ^ (case tvs of [] => "" | _ => "(" ^ String.concatWith ", " tvs ^ ") ")
                                          ^ longidToString id ^ " = " ^ tyToString t) clauses)

  and specsToString specs = String.concatWith " " (List.map specToString specs)

  and specToString sp =
    let
      fun tyvars [] = "" | tyvars vs = "(" ^ String.concatWith ", " vs ^ ") "
    in
      case sp of
        SpecVal (ds, _, _) => "val " ^ String.concatWith " and " (List.map (fn (n, t, _) => n ^ " : " ^ tyToString t) ds)
      | SpecType (ds, _, _) => "type " ^ String.concatWith " and " (List.map (fn (tvs, n, _) => tyvars tvs ^ n) ds)
      | SpecEqtype (ds, _, _) => "eqtype " ^ String.concatWith " and " (List.map (fn (tvs, n, _) => tyvars tvs ^ n) ds)
      | SpecDatatype (dbs, _, _) => decToString (DDatatype (dbs, [], Source.noSpan, noId))
      | SpecDatatypeRepl (n, id, _, _) => "datatype " ^ n ^ " = datatype " ^ longidToString id
      | SpecException (ds, _, _) =>
          "exception " ^ String.concatWith " and " (List.map (fn (n, NONE, _) => n | (n, SOME t, _) => n ^ " of " ^ tyToString t) ds)
      | SpecStructure (ds, _, _) =>
          "structure " ^ String.concatWith " and " (List.map (fn (n, s, _) => n ^ " : " ^ sigexpToString s) ds)
      | SpecInclude (s, _, _) => "include " ^ sigexpToString s
      | SpecSharingType (ids, _, _) => "sharing type " ^ String.concatWith " = " (List.map longidToString ids)
      | SpecSharing (ids, _, _) => "sharing " ^ String.concatWith " = " (List.map longidToString ids)
    end
end
