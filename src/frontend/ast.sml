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
    | SString of string
    | SChar of char

  (* Resolved status of a value identifier, filled by elaboration. *)
  datatype varinfo =
      VLocal of int                             (* variable stamp *)
    | VGlobal of int                            (* top-level variable stamp *)
    | VCon of coninfo
    | VExn of exninfo
    | VBuiltin of string * Types.ty             (* builtin operator (possibly overloaded) and its operand type *)

  and patinfo =
      PIVar of int * bool                       (* stamp, isGlobal *)
    | PICon of coninfo
    | PIExn of exninfo

  withtype coninfo = {name : string, tag : int, hasArg : bool, ncons : int, isRef : bool}
       and exninfo = {name : string, stamp : int, isGlobal : bool, hasArg : bool, builtin : int option}

  datatype exp =
      EScon of scon * span
    | EVar of longid * varinfo option ref * span
    | ERecord of (string * exp) list * span
    | ETuple of exp list * span                 (* including () *)
    | ESelect of string * Types.ty option ref * span   (* #lab *)
    | EList of exp list * span
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
    | EFn of mrule list * span
    | EPrim of string * ty * span               (* _prim "name" : ty *)

  and pat =
      PWild of span
    | PScon of scon * span
    | PVar of longid * patinfo option ref * span          (* variable or nullary constructor *)
    | PRecord of (string * pat) list * bool * Types.ty option ref * span   (* fields, flexible, full record type *)
    | PTuple of pat list * span
    | PList of pat list * span
    | PApp of longid * patinfo option ref * pat * span    (* constructor application *)
    | PTyped of pat * ty * span
    | PLayered of string * ty option * pat * patinfo option ref * span

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
    | DException of exbind list * span
    | DLocal of dec list * dec list * span
    | DOpen of longid list * span
    | DInfix of int * string list * span
    | DInfixr of int * string list * span
    | DNonfix of string list * span
    | DStructure of string * strexp * span

  and strexp =
      StrStruct of dec list * span
    | StrId of longid * span

  and exbind =
      ExnDecl of string * ty option * patinfo option ref * span
    | ExnRepl of string * longid * patinfo option ref * span

  withtype mrule = pat * exp
       and clause = {pats : pat list, resty : ty option, body : exp}
       and fundef = {name : string, clauses : {pats : pat list, resty : ty option, body : exp} list,
                     info : patinfo option ref, span : span}
       and typbind = {tyvars : string list, name : string, ty : ty, span : span}
       and datbind = {tyvars : string list, name : string, cons : (string * ty option * span) list, span : span}

  type program = dec list

  fun spanOfExp e =
    case e of
      EScon (_, s) => s | EVar (_, _, s) => s | ERecord (_, s) => s | ETuple (_, s) => s
    | ESelect (_, _, s) => s | EList (_, s) => s | ESeq (_, s) => s | ELet (_, _, s) => s
    | EApp (_, _, s) => s | ETyped (_, _, s) => s | EAndalso (_, _, s) => s
    | EOrelse (_, _, s) => s | EHandle (_, _, s) => s | ERaise (_, s) => s
    | EIf (_, _, _, s) => s | EWhile (_, _, s) => s | ECase (_, _, s) => s
    | EFn (_, s) => s | EPrim (_, _, s) => s

  fun spanOfPat p =
    case p of
      PWild s => s | PScon (_, s) => s | PVar (_, _, s) => s | PRecord (_, _, _, s) => s
    | PTuple (_, s) => s | PList (_, s) => s | PApp (_, _, _, s) => s | PTyped (_, _, s) => s
    | PLayered (_, _, _, _, s) => s

  fun spanOfTy t =
    case t of
      TyVar (_, s) => s | TyRecord (_, s) => s | TyTuple (_, s) => s | TyCon (_, _, s) => s
    | TyArrow (_, _, s) => s

  fun spanOfDec d =
    case d of
      DVal (_, _, s) => s | DValRec (_, _, s) => s | DFun (_, _, s) => s | DType (_, s) => s
    | DDatatype (_, _, s) => s | DDatatypeRepl (_, _, s) => s | DException (_, s) => s
    | DLocal (_, _, s) => s | DOpen (_, s) => s | DInfix (_, _, s) => s | DInfixr (_, _, s) => s
    | DNonfix (_, s) => s | DStructure (_, _, s) => s

  (* --- debugging printer (used by --dump-ast) --- *)
  fun sconToString sc =
    case sc of
      SInt i => IntInf.toString i
    | SWord w => "0w" ^ IntInf.toString w
    | SReal r => r
    | SString s => "\"" ^ String.toString s ^ "\""
    | SChar c => "#\"" ^ Char.toString c ^ "\""

  fun expToString e =
    case e of
      EScon (sc, _) => sconToString sc
    | EVar (id, _, _) => longidToString id
    | ERecord (fields, _) => "{" ^ String.concatWith ", " (List.map (fn (l, e) => l ^ " = " ^ expToString e) fields) ^ "}"
    | ETuple (es, _) => "(" ^ String.concatWith ", " (List.map expToString es) ^ ")"
    | ESelect (l, _, _) => "#" ^ l
    | EList (es, _) => "[" ^ String.concatWith ", " (List.map expToString es) ^ "]"
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
    | EFn (m, _) => "(fn " ^ matchToString m ^ ")"
    | EPrim (n, t, _) => "(_prim \"" ^ n ^ "\" : " ^ tyToString t ^ ")"

  and matchToString rules =
    String.concatWith " | " (List.map (fn (p, e) => patToString p ^ " => " ^ expToString e) rules)

  and patToString p =
    case p of
      PWild _ => "_"
    | PScon (sc, _) => sconToString sc
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
      | DStructure (n, StrStruct (ds, _), _) =>
          "structure " ^ n ^ " = struct " ^ String.concatWith " " (List.map decToString ds) ^ " end"
      | DStructure (n, StrId (id, _), _) => "structure " ^ n ^ " = " ^ longidToString id
    end
end
