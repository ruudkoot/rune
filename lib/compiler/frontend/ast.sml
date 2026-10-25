(* Abstract syntax. Nodes carry mutable annotation slots that elaboration
   fills in (resolved identifier status, record types) for the translator. *)
structure Ast =
struct
  type span = Source.span
  type longid = string list * string          (* structure path, name *)

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
      EScon of scon * Types.ty option ref * span   (* the type of an int or word constant, filled by elaboration *)
    | EVar of longid * varinfo option ref * span
    | ERecord of (string * exp) list * span
    | ETuple of exp list * span                 (* including () *)
    | ESelect of string * Types.ty option ref * span   (* #lab *)
    | EList of exp list * Types.ty option ref * span   (* the type of the list, filled by elaboration *)
    | ESeq of exp list * span
    | ELet of dec list * exp * span
    | EApp of exp * exp * span
    | ETyped of exp * ty * span
    | EAndalso of exp * exp * span
    | EOrelse of exp * exp * span
    | EHandle of exp * mrule list * span
    | ERaise of exp * span
    | EIf of exp * exp * exp * span
    | EWhile of exp * exp * span
    | ECase of exp * mrule list * span
    | EFn of mrule list * Types.ty option ref * span   (* the type of the function, filled by elaboration *)
    | EPrim of string * ty * Types.ty option ref * span   (* _prim "name" : ty, and ty elaborated *)

  and pat =
      PWild of span
    | PScon of scon * Types.ty option ref * span
    | PVar of longid * patinfo option ref * span          (* variable or nullary constructor *)
    | PRecord of (string * pat) list * bool * Types.ty option ref * span   (* fields, flexible, full record type *)
    | PTuple of pat list * span
    | PList of pat list * span
    | PApp of longid * patinfo option ref * pat * span    (* constructor application *)
    | PTyped of pat * ty * span
    | PLayered of string * ty option * pat * patinfo option ref * span
    | POr of pat list * span                              (* (p1 | ... | pn), with --or-patterns *)

  and ty =
      TyVar of string * span
    | TyRecord of (string * ty) list * span
    | TyTuple of ty list * span
    | TyCon of ty list * longid * span
    | TyArrow of ty * ty * span

  and dec =
      DVal of string list * (pat * exp) list * span
    | DValRec of string list * (pat * exp) list * span
    | DFun of string list * fundef list * span
    | DType of typbind list * span
    | DDatatype of datbind list * typbind list * span
    | DDatatypeRepl of string * longid * span
    | DAbstype of datbind list * typbind list * dec list * span
    | DException of exbind list * span
    | DLocal of dec list * dec list * span
    | DOpen of longid list * span
    | DInfix of int * string list * span
    | DInfixr of int * string list * span
    | DNonfix of string list * span
    | DOverload of {kind : string, strid : string list, literal : ovliteral, span : span}   (* _overload *)
    | DStructure of strbind list * span
    | DSignature of sigbind list * span
    | DFunctor of funbind list * span

  and strexp =
      StrStruct of dec list * span
    | StrId of longid * span
    | StrAscribe of strexp * sigexp * bool * span            (* true = opaque (:>) *)
    | StrApp of string * strexp * span                       (* functor application *)
    | StrLet of dec list * strexp * span
    | StrDynamic of dynamicFrom * sigexp * dynamic option ref * span   (* _dynamic "path" : SIG, _virtual : SIG (docs/units.md, Dynamic modules) *)
    | StrExport of string * sigexp * strexp * dynamic option ref * span    (* _export structure X : SIG = strexp *)

  and sigexp =
      SigSig of spec list * span
    | SigId of string * span
    | SigWhere of sigexp * (string list * longid * ty * span) list * span   (* where type tyvarseq longtycon = ty *)

  and spec =
      SpecVal of (string * ty * span) list * span
    | SpecType of (string list * string * span) list * span
    | SpecEqtype of (string list * string * span) list * span
    | SpecDatatype of datbind list * span
    | SpecDatatypeRepl of string * longid * span
    | SpecException of (string * ty option * span) list * span
    | SpecStructure of (string * sigexp * span) list * span
    | SpecInclude of sigexp * span
    | SpecSharingType of longid list * span
    | SpecSharing of longid list * span                      (* structure sharing (derived form) *)

  and exbind =
      ExnDecl of string * ty option * patinfo option ref * span
    | ExnRepl of string * longid * patinfo option ref * span

  withtype mrule = pat * exp
       and clause = {pats : pat list, resty : ty option, body : exp}
       and fundef = {name : string, clauses : {pats : pat list, resty : ty option, body : exp} list,
                     info : patinfo option ref, span : span}
       and typbind = {tyvars : string list, name : string, ty : ty, span : span}
       and datbind = {tyvars : string list, name : string, cons : (string * ty option * span) list, span : span}
       and strbind = {name : string, strexp : strexp, span : span}
       and sigbind = {name : string, sigexp : sigexp, span : span}
       and funbind = {name : string, param : string option, paramSig : sigexp, body : strexp, span : span}
       (* what elaboration finds of a dynamic module's boundary: the
          fingerprint of the signature's ABI, its record of slots
          (dynamicRecord) and the global of RuneDynamic.load or
          RuneDynamic.export, and a global of the client's for the record *)
       and dynamic = {fingerprint : string, slots : dynamicRecord, via : int, temp : int, reloadable : bool}

  type program = dec list

  fun spanOfExp e =
    case e of
      EScon (_, _, s) => s | EVar (_, _, s) => s | ERecord (_, s) => s | ETuple (_, s) => s
    | ESelect (_, _, s) => s | EList (_, _, s) => s | ESeq (_, s) => s | ELet (_, _, s) => s
    | EApp (_, _, s) => s | ETyped (_, _, s) => s | EAndalso (_, _, s) => s
    | EOrelse (_, _, s) => s | EHandle (_, _, s) => s | ERaise (_, s) => s
    | EIf (_, _, _, s) => s | EWhile (_, _, s) => s | ECase (_, _, s) => s
    | EFn (_, _, s) => s | EPrim (_, _, _, s) => s

  fun spanOfPat p =
    case p of
      PWild s => s | PScon (_, _, s) => s | PVar (_, _, s) => s | PRecord (_, _, _, s) => s
    | PTuple (_, s) => s | PList (_, s) => s | PApp (_, _, _, s) => s | PTyped (_, _, s) => s
    | PLayered (_, _, _, _, s) => s | POr (_, s) => s

  (* The alternatives of a pattern: the patterns without or-patterns that it
     matches as, one for every choice of an alternative in each of its
     or-patterns, in order. A pattern without one is its only alternative;
     the alternatives share the annotation slots of the pattern. *)
  fun alternatives (p : pat) : pat list =
    let
      (* every choice of an element from each list, in order *)
      fun choices [] = [[]]
        | choices (xs :: rest) =
          let val tails = choices rest
          in List.concat (List.map (fn x => List.map (fn t => x :: t) tails) xs) end
    in
      case p of
        POr (ps, _) => List.concat (List.map alternatives ps)
      | PRecord (fields, flex, slot, sp) =>
          List.map (fn ps => PRecord (ListPair.zip (List.map #1 fields, ps), flex, slot, sp))
                   (choices (List.map (alternatives o #2) fields))
      | PTuple (ps, sp) => List.map (fn ps => PTuple (ps, sp)) (choices (List.map alternatives ps))
      | PList (ps, sp) => List.map (fn ps => PList (ps, sp)) (choices (List.map alternatives ps))
      | PApp (id, slot, arg, sp) => List.map (fn a => PApp (id, slot, a, sp)) (alternatives arg)
      | PTyped (q, t, sp) => List.map (fn q => PTyped (q, t, sp)) (alternatives q)
      | PLayered (v, t, q, slot, sp) => List.map (fn q => PLayered (v, t, q, slot, sp)) (alternatives q)
      | _ => [p]
    end

  fun hasOr (p : pat) : bool =
    case p of
      POr _ => true
    | PRecord (fields, _, _, _) => List.exists (hasOr o #2) fields
    | PTuple (ps, _) => List.exists hasOr ps
    | PList (ps, _) => List.exists hasOr ps
    | PApp (_, _, arg, _) => hasOr arg
    | PTyped (q, _, _) => hasOr q
    | PLayered (_, _, q, _, _) => hasOr q
    | _ => false

  fun spanOfTy t =
    case t of
      TyVar (_, s) => s | TyRecord (_, s) => s | TyTuple (_, s) => s | TyCon (_, _, s) => s
    | TyArrow (_, _, s) => s

  fun spanOfDec d =
    case d of
      DVal (_, _, s) => s | DValRec (_, _, s) => s | DFun (_, _, s) => s | DType (_, s) => s
    | DDatatype (_, _, s) => s | DDatatypeRepl (_, _, s) => s | DAbstype (_, _, _, s) => s | DException (_, s) => s
    | DLocal (_, _, s) => s | DOpen (_, s) => s | DInfix (_, _, s) => s | DInfixr (_, _, s) => s
    | DNonfix (_, s) => s | DOverload {span = s, ...} => s | DStructure (_, s) => s | DSignature (_, s) => s | DFunctor (_, s) => s

  fun spanOfStrexp e =
    case e of
      StrStruct (_, s) => s | StrId (_, s) => s | StrAscribe (_, _, _, s) => s
    | StrApp (_, _, s) => s | StrLet (_, _, s) => s
    | StrDynamic (_, _, _, s) => s | StrExport (_, _, _, _, s) => s

  fun spanOfSigexp e =
    case e of
      SigSig (_, s) => s | SigId (_, s) => s | SigWhere (_, _, s) => s

  (* The variables of a pattern allowed on the left of a recursive value
     binding (Section 2.9 restricts only the expression): variables, layered
     and typed patterns and wildcards. Returns the variables with their
     annotation slots and the type annotations met, or NONE otherwise. *)
  fun recBindVars (p : pat) : ((string * patinfo option ref * span) list * ty list) option =
    case p of
      PVar (([], name), slot, sp) => SOME ([(name, slot, sp)], [])
    | PWild _ => SOME ([], [])
    | PTyped (p, t, _) => (case recBindVars p of SOME (vs, ts) => SOME (vs, t :: ts) | NONE => NONE)
    | PLayered (name, tyopt, p, slot, sp) =>
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
      EScon (sc, _, _) => sconToString sc
    | EVar (id, _, _) => longidToString id
    | ERecord (fields, _) => "{" ^ String.concatWith ", " (List.map (fn (l, e) => l ^ " = " ^ expToString e) fields) ^ "}"
    | ETuple (es, _) => "(" ^ String.concatWith ", " (List.map expToString es) ^ ")"
    | ESelect (l, _, _) => "#" ^ l
    | EList (es, _, _) => "[" ^ String.concatWith ", " (List.map expToString es) ^ "]"
    | ESeq (es, _) => "(" ^ String.concatWith "; " (List.map expToString es) ^ ")"
    | ELet (ds, e, _) => "let " ^ String.concatWith " " (List.map decToString ds) ^ " in " ^ expToString e ^ " end"
    | EApp (f, a, _) => "(" ^ expToString f ^ " " ^ expToString a ^ ")"
    | ETyped (e, t, _) => "(" ^ expToString e ^ " : " ^ tyToString t ^ ")"
    | EAndalso (a, b, _) => "(" ^ expToString a ^ " andalso " ^ expToString b ^ ")"
    | EOrelse (a, b, _) => "(" ^ expToString a ^ " orelse " ^ expToString b ^ ")"
    | EHandle (e, m, _) => "(" ^ expToString e ^ " handle " ^ matchToString m ^ ")"
    | ERaise (e, _) => "(raise " ^ expToString e ^ ")"
    | EIf (a, b, c, _) => "(if " ^ expToString a ^ " then " ^ expToString b ^ " else " ^ expToString c ^ ")"
    | EWhile (a, b, _) => "(while " ^ expToString a ^ " do " ^ expToString b ^ ")"
    | ECase (e, m, _) => "(case " ^ expToString e ^ " of " ^ matchToString m ^ ")"
    | EFn (m, _, _) => "(fn " ^ matchToString m ^ ")"
    | EPrim (n, t, _, _) => "(_prim \"" ^ n ^ "\" : " ^ tyToString t ^ ")"

  and matchToString rules =
    String.concatWith " | " (List.map (fn (p, e) => patToString p ^ " => " ^ expToString e) rules)

  and patToString p =
    case p of
      PWild _ => "_"
    | PScon (sc, _, _) => sconToString sc
    | PVar (id, _, _) => longidToString id
    | PRecord (fields, flex, _, _) =>
        "{" ^ String.concatWith ", " (List.map (fn (l, p) => l ^ " = " ^ patToString p) fields)
        ^ (if flex then ", ..." else "") ^ "}"
    | PTuple (ps, _) => "(" ^ String.concatWith ", " (List.map patToString ps) ^ ")"
    | PList (ps, _) => "[" ^ String.concatWith ", " (List.map patToString ps) ^ "]"
    | PApp (id, _, p, _) => "(" ^ longidToString id ^ " " ^ patToString p ^ ")"
    | PTyped (p, t, _) => "(" ^ patToString p ^ " : " ^ tyToString t ^ ")"
    | PLayered (v, NONE, p, _, _) => "(" ^ v ^ " as " ^ patToString p ^ ")"
    | PLayered (v, SOME t, p, _, _) => "(" ^ v ^ " : " ^ tyToString t ^ " as " ^ patToString p ^ ")"
    | POr (ps, _) => "(" ^ String.concatWith " | " (List.map patToString ps) ^ ")"

  and tyToString t =
    case t of
      TyVar (v, _) => v
    | TyRecord (fields, _) => "{" ^ String.concatWith ", " (List.map (fn (l, t) => l ^ " : " ^ tyToString t) fields) ^ "}"
    | TyTuple (ts, _) => "(" ^ String.concatWith " * " (List.map tyToString ts) ^ ")"
    | TyCon ([], id, _) => longidToString id
    | TyCon (ts, id, _) => "(" ^ String.concatWith ", " (List.map tyToString ts) ^ ") " ^ longidToString id
    | TyArrow (a, b, _) => "(" ^ tyToString a ^ " -> " ^ tyToString b ^ ")"

  and decToString d =
    let
      fun tyvars [] = "" | tyvars vs = "(" ^ String.concatWith ", " vs ^ ") "
      fun binds bs = String.concatWith " and " (List.map (fn (p, e) => patToString p ^ " = " ^ expToString e) bs)
    in
      case d of
        DVal (tvs, bs, _) => "val " ^ tyvars tvs ^ binds bs
      | DValRec (tvs, bs, _) => "val " ^ tyvars tvs ^ "rec " ^ binds bs
      | DFun (tvs, fs, _) =>
          "fun " ^ tyvars tvs ^
          String.concatWith " and "
            (List.map (fn {name, clauses, ...} =>
                          String.concatWith " | "
                            (List.map (fn {pats, resty, body} =>
                                          name ^ " " ^ String.concatWith " " (List.map patToString pats)
                                          ^ (case resty of NONE => "" | SOME t => " : " ^ tyToString t)
                                          ^ " = " ^ expToString body) clauses)) fs)
      | DType (tbs, _) =>
          "type " ^ String.concatWith " and " (List.map (fn {tyvars = tvs, name, ty, ...} => tyvars tvs ^ name ^ " = " ^ tyToString ty) tbs)
      | DDatatype (dbs, tbs, _) =>
          "datatype " ^
          String.concatWith " and "
            (List.map (fn {tyvars = tvs, name, cons, ...} =>
                          tyvars tvs ^ name ^ " = " ^
                          String.concatWith " | "
                            (List.map (fn (c, NONE, _) => c | (c, SOME t, _) => c ^ " of " ^ tyToString t) cons)) dbs)
          ^ (case tbs of [] => "" | _ => " withtype " ^ decToString (DType (tbs, Source.noSpan)))
      | DDatatypeRepl (n, id, _) => "datatype " ^ n ^ " = datatype " ^ longidToString id
      | DAbstype (dbs, tbs, ds, _) =>
          "abs" ^ decToString (DDatatype (dbs, tbs, Source.noSpan)) ^ " with "
          ^ String.concatWith " " (List.map decToString ds) ^ " end"
      | DException (ebs, _) =>
          "exception " ^
          String.concatWith " and "
            (List.map (fn ExnDecl (n, NONE, _, _) => n
                        | ExnDecl (n, SOME t, _, _) => n ^ " of " ^ tyToString t
                        | ExnRepl (n, id, _, _) => n ^ " = " ^ longidToString id) ebs)
      | DLocal (d1, d2, _) =>
          "local " ^ String.concatWith " " (List.map decToString d1) ^ " in "
          ^ String.concatWith " " (List.map decToString d2) ^ " end"
      | DOpen (ids, _) => "open " ^ String.concatWith " " (List.map longidToString ids)
      | DInfix (p, ids, _) => "infix " ^ Int.toString p ^ " " ^ String.concatWith " " ids
      | DInfixr (p, ids, _) => "infixr " ^ Int.toString p ^ " " ^ String.concatWith " " ids
      | DNonfix (ids, _) => "nonfix " ^ String.concatWith " " ids
      | DOverload {kind, strid, ...} => "_overload " ^ kind ^ " " ^ String.concatWith "." strid
      | DStructure (bs, _) =>
          "structure " ^ String.concatWith " and " (List.map (fn {name, strexp, ...} => name ^ " = " ^ strexpToString strexp) bs)
      | DSignature (bs, _) =>
          "signature " ^ String.concatWith " and " (List.map (fn {name, sigexp, ...} => name ^ " = " ^ sigexpToString sigexp) bs)
      | DFunctor (bs, _) =>
          "functor " ^
          String.concatWith " and "
            (List.map (fn {name, param, paramSig, body, ...} =>
                          name ^ " (" ^ (case param of SOME p => p ^ " : " ^ sigexpToString paramSig
                                                       | NONE => (case paramSig of SigSig (ss, _) => specsToString ss | _ => sigexpToString paramSig))
                          ^ ") = " ^ strexpToString body) bs)
    end

  and strexpToString e =
    case e of
      StrStruct (ds, _) => "struct " ^ String.concatWith " " (List.map decToString ds) ^ " end"
    | StrId (id, _) => longidToString id
    | StrAscribe (e, s, opaque, _) => strexpToString e ^ (if opaque then " :> " else " : ") ^ sigexpToString s
    | StrApp (f, a, _) => f ^ " (" ^ strexpToString a ^ ")"
    | StrLet (ds, e, _) => "let " ^ String.concatWith " " (List.map decToString ds) ^ " in " ^ strexpToString e ^ " end"
    | StrDynamic (DynamicFile path, s, _, _) => "_dynamic \"" ^ String.toString path ^ "\" : " ^ sigexpToString s
    | StrDynamic (DynamicVirtual _, s, _, _) => "_virtual : " ^ sigexpToString s
    | StrExport (_, s, e, _, _) => "_export " ^ sigexpToString s ^ " (" ^ strexpToString e ^ ")"

  and sigexpToString s =
    case s of
      SigSig (specs, _) => "sig " ^ specsToString specs ^ " end"
    | SigId (n, _) => n
    | SigWhere (s, clauses, _) =>
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
        SpecVal (ds, _) => "val " ^ String.concatWith " and " (List.map (fn (n, t, _) => n ^ " : " ^ tyToString t) ds)
      | SpecType (ds, _) => "type " ^ String.concatWith " and " (List.map (fn (tvs, n, _) => tyvars tvs ^ n) ds)
      | SpecEqtype (ds, _) => "eqtype " ^ String.concatWith " and " (List.map (fn (tvs, n, _) => tyvars tvs ^ n) ds)
      | SpecDatatype (dbs, _) => decToString (DDatatype (dbs, [], Source.noSpan))
      | SpecDatatypeRepl (n, id, _) => "datatype " ^ n ^ " = datatype " ^ longidToString id
      | SpecException (ds, _) =>
          "exception " ^ String.concatWith " and " (List.map (fn (n, NONE, _) => n | (n, SOME t, _) => n ^ " of " ^ tyToString t) ds)
      | SpecStructure (ds, _) =>
          "structure " ^ String.concatWith " and " (List.map (fn (n, s, _) => n ^ " : " ^ sigexpToString s) ds)
      | SpecInclude (s, _) => "include " ^ sigexpToString s
      | SpecSharingType (ids, _) => "sharing type " ^ String.concatWith " = " (List.map longidToString ids)
      | SpecSharing (ids, _) => "sharing " ^ String.concatWith " = " (List.map longidToString ids)
    end
end
