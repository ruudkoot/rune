(* The abstract syntax of Haskell 98, the Report's chapter 10, before
   names and fixity are resolved (the haskell98 roadmap's D28).

   It keeps what the source says: a span on every node, parentheses as
   nodes, operators in flat sequences with negation as an item (fixity is
   resolved after names, D29), literals and contexts as written. Every
   node also has an annotation that holds its own tokens, those of the
   source that are not in a node below it, each with the trivia before
   it: comments, pragmas, white space, and the braces and semicolons of
   layout, written or not. From the annotations `HsPrint.exact` prints a
   module as its file, byte for byte. A node that a tool makes has
   `noAnn`, and is printed as `HsPrint.explicit` prints it.

   Patterns are read relaxed and checked after, so a sequence of patterns
   with operators, `PSeq`, holds constructor operators only, and `PJux`
   never leaves the parser.

   Area: Languages *)
signature HS_AST =
sig
  (* A token of the source as a node owns it: the bytes it covers, none
     for one of layout's, and the trivia before it. *)
  type tok = {trivia : HsToken.trivium list, start : int, stop : int}

  (* A node's annotation: its span, and its own tokens in the order of the
     source. *)
  type ann = {span : HsSource.span, toks : tok list}

  (* The annotation of a node that no source gave, and of every node of a
     tree read with annotations off. *)
  val noAnn : ann

  (* A name as written: its qualifier, `""` for none, and the name. The
     special constructors are names too: `()`, `[]`, `(,)`, `(,,)` and on,
     `(->)`, and `:`. *)
  type qname = {qual : string, name : string}

  (* An identifier or an operator of the source, with its annotation,
     whose tokens are the parentheses or backquotes around it, if any,
     and the name. *)
  datatype name = Name of ann * qname

  (* A literal: its value, and its text as written. *)
  datatype lit_ =
      LInt of IntInf.int * string    (* an integer *)
    | LFloat of string               (* a floating-point literal, whose value is a rational *)
    | LChar of int * string          (* a character, by its code point *)
    | LString of int list * string   (* a string, by its code points *)
  (* A literal of the source. *)
  datatype lit = Lit of ann * lit_

  (* An operator where an operator goes: a variable's, `+` or `` `div` ``,
     or a constructor's, `:+` or `` `Cons` ``. *)
  datatype qop = VarOp of name | ConOp of name

  (* A type, a context among them, as written. *)
  datatype ty = T of ann * ty_
  (* The forms of a type. *)
  and ty_ =
      TVar of name                   (* a type variable *)
    | TCon of name                   (* a type constructor, `()`, `[]`, `(->)` and the tuples' among them *)
    | TApp of ty * ty                (* an application *)
    | TFun of ty * ty                (* `t1 -> t2` *)
    | TList of ty                    (* `[t]` *)
    | TTuple of ty list              (* `(t1, ..., tn)` *)
    | TParen of ty                   (* `(t)` *)

  (* A pattern. *)
  datatype pat = P of ann * pat_
  (* The forms of a pattern. *)
  and pat_ =
      PVar of name                   (* a variable *)
    | PWild                          (* `_` *)
    | PLit of lit                    (* a literal *)
    | PNegLit of lit                 (* `-` and a numeric literal *)
    | PCon of name * pat list        (* a constructor and its arguments *)
    | PRec of name * (name * pat) list (* `C {f1 = p1, ...}` *)
    | PTuple of pat list             (* `(p1, ..., pn)` *)
    | PList of pat list              (* `[p1, ..., pn]` *)
    | PParen of pat                  (* `(p)` *)
    | PAs of name * pat              (* `x@p` *)
    | PLazy of pat                   (* `~p` *)
    | PNPlusK of name * lit          (* `n+k` *)
    | PSeq of patitem list           (* operands and constructor operators, before fixity *)
    | PJux of pat list               (* juxtaposed patterns, between the parser's two stages only *)
  (* An item of a sequence of patterns. *)
  and patitem = PA of pat | PO of qop

  (* An expression. *)
  datatype exp = E of ann * exp_
  (* The forms of an expression. *)
  and exp_ =
      EVar of name                   (* a variable, `(+)` among them *)
    | ECon of name                   (* a constructor, `()` and `[]` among them *)
    | ELit of lit                    (* a literal *)
    | EApp of exp * exp              (* an application *)
    | ESeq of expitem list           (* operands, operators and negations, before fixity *)
    | ELam of pat list * exp         (* `\p1 ... pn -> e` *)
    | ELet of decl list * exp        (* `let ds in e` *)
    | EIf of exp * exp * exp         (* `if e1 then e2 else e3` *)
    | ECase of exp * alt list        (* `case e of alts` *)
    | EDo of stmt list               (* `do stmts` *)
    | ETuple of exp list             (* `(e1, ..., en)` *)
    | EParen of exp                  (* `(e)` *)
    | EList of exp list              (* `[e1, ..., en]` *)
    | EEnum of exp * exp option * exp option (* `[e1, e2 .. e3]` and its shorter forms *)
    | EComp of exp * stmt list       (* `[e | quals]` *)
    | ELeftSec of exp * qop          (* `(e op)` *)
    | ERightSec of qop * exp         (* `(op e)` *)
    | ERecCon of name * (name * exp) list (* `C {f1 = e1, ...}` *)
    | ERecUpd of exp * (name * exp) list (* `e {f1 = e1, ...}` *)
    | ESig of exp * ty option * ty   (* `e :: context => t` *)
  (* An item of a sequence: an operand, an operator, or `-` as negation. *)
  and expitem = EA of exp | EO of qop | ENeg
  (* A statement of `do`, or a qualifier of a comprehension. *)
  and stmt = S of ann * stmt_
  (* The forms of a statement. *)
  and stmt_ =
      SBind of pat * exp             (* `p <- e` *)
    | SLet of decl list              (* `let ds` *)
    | SExp of exp                    (* `e` *)
  (* An alternative of `case`: `p rhs`, where the right-hand side's
     arrow is `->`. *)
  and alt = Alt of ann * pat * rhs
  (* A right-hand side: an expression or guards, with a `where`. *)
  and rhs = Rhs of ann * rhs_
  (* The forms of a right-hand side. *)
  and rhs_ =
      Plain of exp * decl list option (* `= e where ds` *)
    | Guarded of guard list * decl list option (* `| g1 = e1 ... where ds` *)
  (* A guard and its expression: `| g = e`. *)
  and guard = Guard of ann * exp * exp
  (* The left-hand side of a function's equation. *)
  and funlhs = F of ann * funlhs_
  (* The forms of a left-hand side. *)
  and funlhs_ =
      FPrefix of name * pat list     (* `f p1 ... pn` *)
    | FInfix of pat * qop * pat      (* `p1 op p2` *)
    | FParen of funlhs * pat list    (* `(lhs) p1 ... pn` *)
  (* A declaration. *)
  and decl = D of ann * decl_
  (* The forms of a declaration. *)
  and decl_ =
      DSig of name list * ty option * ty (* `v1, ..., vn :: context => t` *)
    | DFixity of fixity * lit option * qop list (* `infixl 6 +, -` *)
    | DFun of funlhs * rhs           (* an equation of a function *)
    | DPat of pat * rhs              (* a pattern binding, a variable's among them *)
    | DType of name * name list * ty (* `type T a = t` *)
    | DData of ty option * name * name list * constr list * deriv option (* `data` *)
    | DNewtype of ty option * name * name list * constr * deriv option (* `newtype` *)
    | DClass of ty option * name * name * decl list option (* `class context => C a where ds` *)
    | DInstance of ty option * name * ty * decl list option (* `instance context => C t where ds` *)
    | DDefault of ty list            (* `default (t1, ..., tn)` *)
  (* The associativity of a fixity declaration. *)
  and fixity = Infix | Infixl | Infixr
  (* A constructor of `data` or `newtype`. *)
  and constr = C of ann * constr_
  (* The forms of a constructor. *)
  and constr_ =
      CPlain of name * (bool * ty) list (* `K t1 ... tn`, each argument strict with `!` or not *)
    | CInfix of (bool * ty) * name * (bool * ty) (* `t1 :+ t2` *)
    | CRec of name * field list      (* `K {f1, f2 :: t, ...}` *)
  (* The fields of a record constructor that one type has. *)
  and field = Field of ann * name list * bool * ty
  (* A `deriving` clause: whether its classes are in parentheses, and
     them. *)
  and deriv = Deriv of ann * bool * name list

  (* What an export or an import names. *)
  datatype entity = Ent of ann * entity_
  (* The forms of an entity. *)
  and entity_ =
      EntVar of name                 (* a variable *)
    | EntType of name * sub option   (* a type or a class, with its constructors, fields or methods *)
    | EntModule of name              (* `module M`, in an export list *)
  (* The constructors or methods an entity names: `(..)`, or a list. *)
  and sub = SubAll | SubList of name list

  (* An import declaration. *)
  datatype import = Import of ann * {qualified : bool, module : name, as_ : name option, hiding : bool,
                                     spec : entity list option}

  (* A module: its header, if any, its imports and its declarations. The
     annotation's last token covers no byte and holds the trivia at the end
     of the file. *)
  datatype module = Module of ann * {name : name option, exports : entity list option,
                                     imports : import list, decls : decl list}

  (* `qname (qual, name)` is the name `name` qualified by `qual`, `""` for
     none. *)
  val qname : string * string -> qname

  (* `nameText q` is the name as the source writes it in a variable's
     place, qualified: `M.x` or `+`. *)
  val nameText : qname -> string

  (* `isSymbolic q` is whether the name of `q` is an operator's rather
     than an identifier's: its first character is a symbol or `:`. The
     special constructors but `:` are not. *)
  val isSymbolic : qname -> bool

  (* `isSpecial q` is whether `q` is one of the special constructors that
     are written with brackets: `()`, `[]`, the tuples', `(->)`. *)
  val isSpecial : qname -> bool

  (* `spanOfExp e`, `spanOfPat p`, `spanOfTy t` and `spanOfDecl d` are the
     spans of the nodes. *)
  val spanOfExp : exp -> HsSource.span
  val spanOfPat : pat -> HsSource.span
  val spanOfTy : ty -> HsSource.span
  val spanOfDecl : decl -> HsSource.span
end
