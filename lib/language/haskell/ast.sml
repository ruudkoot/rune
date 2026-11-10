(* Implements: HS_AST *)
structure HsAst :> HS_AST =
struct
  type tok = {trivia : HsToken.trivium list, start : int, stop : int}
  type ann = {span : HsSource.span, toks : tok list}
  val noAnn : ann = {span = HsSource.noSpan, toks = []}

  type qname = {qual : string, name : string}
  datatype name = Name of ann * qname

  datatype lit_ =
      LInt of IntInf.int * string
    | LFloat of string
    | LChar of int * string
    | LString of int list * string
  datatype lit = Lit of ann * lit_

  datatype qop = VarOp of name | ConOp of name

  datatype ty = T of ann * ty_
  and ty_ =
      TVar of name
    | TCon of name
    | TApp of ty * ty
    | TFun of ty * ty
    | TList of ty
    | TTuple of ty list
    | TParen of ty

  datatype pat = P of ann * pat_
  and pat_ =
      PVar of name
    | PWild
    | PLit of lit
    | PNegLit of lit
    | PCon of name * pat list
    | PRec of name * (name * pat) list
    | PTuple of pat list
    | PList of pat list
    | PParen of pat
    | PAs of name * pat
    | PLazy of pat
    | PNPlusK of name * lit
    | PSeq of patitem list
    | PJux of pat list
  and patitem = PA of pat | PO of qop

  datatype exp = E of ann * exp_
  and exp_ =
      EVar of name
    | ECon of name
    | ELit of lit
    | EApp of exp * exp
    | ESeq of expitem list
    | ELam of pat list * exp
    | ELet of decl list * exp
    | EIf of exp * exp * exp
    | ECase of exp * alt list
    | EDo of stmt list
    | ETuple of exp list
    | EParen of exp
    | EList of exp list
    | EEnum of exp * exp option * exp option
    | EComp of exp * stmt list
    | ELeftSec of exp * qop
    | ERightSec of qop * exp
    | ERecCon of name * (name * exp) list
    | ERecUpd of exp * (name * exp) list
    | ESig of exp * ty option * ty
  and expitem = EA of exp | EO of qop | ENeg
  and stmt = S of ann * stmt_
  and stmt_ =
      SBind of pat * exp
    | SLet of decl list
    | SExp of exp
  and alt = Alt of ann * pat * rhs
  and rhs = Rhs of ann * rhs_
  and rhs_ =
      Plain of exp * decl list option
    | Guarded of guard list * decl list option
  and guard = Guard of ann * exp * exp
  and funlhs = F of ann * funlhs_
  and funlhs_ =
      FPrefix of name * pat list
    | FInfix of pat * qop * pat
    | FParen of funlhs * pat list
  and decl = D of ann * decl_
  and decl_ =
      DSig of name list * ty option * ty
    | DFixity of fixity * lit option * qop list
    | DFun of funlhs * rhs
    | DPat of pat * rhs
    | DType of name * name list * ty
    | DData of ty option * name * name list * constr list * deriv option
    | DNewtype of ty option * name * name list * constr * deriv option
    | DClass of ty option * name * name * decl list option
    | DInstance of ty option * name * ty * decl list option
    | DDefault of ty list
  and fixity = Infix | Infixl | Infixr
  and constr = C of ann * constr_
  and constr_ =
      CPlain of name * (bool * ty) list
    | CInfix of (bool * ty) * name * (bool * ty)
    | CRec of name * field list
  and field = Field of ann * name list * bool * ty
  and deriv = Deriv of ann * bool * name list

  datatype entity = Ent of ann * entity_
  and entity_ =
      EntVar of name
    | EntType of name * sub option
    | EntModule of name
  and sub = SubAll | SubList of name list

  datatype import = Import of ann * {qualified : bool, module : name, as_ : name option, hiding : bool,
                                     spec : entity list option}

  datatype module = Module of ann * {name : name option, exports : entity list option,
                                     imports : import list, decls : decl list}

  fun qname (qual, name) = {qual = qual, name = name}

  fun nameText ({qual, name} : qname) = if qual = "" then name else qual ^ "." ^ name

  fun isSpecial ({name, ...} : qname) =
    name = "()" orelse name = "[]" orelse name = "(->)" orelse String.isPrefix "(," name

  fun isSymbolic (q as {name, ...} : qname) =
    size name > 0 andalso not (isSpecial q) andalso
    (let val c = String.sub (name, 0)
     in
       if Char.ord c < 128 then not (Char.isAlpha c orelse c = #"_")
       else
         case Utf8.decode (name, 0) of
           SOME (cp, _) => HsChar.isSymbol cp
         | NONE => false
     end)

  fun spanOfExp (E ({span, ...}, _)) = span
  fun spanOfPat (P ({span, ...}, _)) = span
  fun spanOfTy (T ({span, ...}, _)) = span
  fun spanOfDecl (D ({span, ...}, _)) = span
end
