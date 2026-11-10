# signature HS_AST

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_AST**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 44 of 44 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/ast\_sig.sml](../../../../../lib/language/haskell/ast_sig.sml) |

## Synopsis

```sml
signature HS_AST
structure HsAst :> HS_AST
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsAst`](../str/HsAst.md) |  | [lib/language/haskell/ast.sml](../../../../../lib/language/haskell/ast.sml) |

The abstract syntax of Haskell 98, the Report's chapter 10, before
names and fixity are resolved (the haskell98 roadmap's D28).

It keeps what the source says: a span on every node, parentheses as
nodes, operators in flat sequences with negation as an item (fixity is
resolved after names, D29), literals and contexts as written. Every
node also has an annotation that holds its own tokens, those of the
source that are not in a node below it, each with the trivia before
it: comments, pragmas, white space, and the braces and semicolons of
layout, written or not. From the annotations [`HsPrint.exact`](../sig/HS_PRINT.md#val-exact) prints a
module as its file, byte for byte. A node that a tool makes has
[`noAnn`](#val-noann), and is printed as [`HsPrint.explicit`](../sig/HS_PRINT.md#val-explicit) prints it.

Patterns are read relaxed and checked after, so a sequence of patterns
with operators, [`PSeq`](#con-pseq), holds constructor operators only, and [`PJux`](#con-pjux)
never leaves the parser.

## Interface

<pre>
signature HS_AST =
sig
  type <a href="#type-tok">tok</a> = {<a href="#fld-tok.trivia">trivia</a> : HsToken.trivium list, <a href="#fld-tok.start">start</a> : int, <a href="#fld-tok.stop">stop</a> : int}
  type <a href="#type-ann">ann</a> = {<a href="#fld-ann.span">span</a> : HsSource.span, <a href="#fld-ann.toks">toks</a> : tok list}
  val <a href="#val-noann">noAnn</a> : ann
  type <a href="#type-qname">qname</a> = {<a href="#fld-qname.qual">qual</a> : string, <a href="#fld-qname.name">name</a> : string}
  datatype <a href="#type-name">name</a> = <a href="#con-name">Name</a> of ann * qname
  datatype <a href="#type-lit_">lit_</a> =
      <a href="#con-lint">LInt</a> of IntInf.int * string
    | <a href="#con-lfloat">LFloat</a> of string
    | <a href="#con-lchar">LChar</a> of int * string
    | <a href="#con-lstring">LString</a> of int list * string
  datatype <a href="#type-lit">lit</a> = <a href="#con-lit">Lit</a> of ann * lit_
  datatype <a href="#type-qop">qop</a> = <a href="#con-varop">VarOp</a> of name | <a href="#con-conop">ConOp</a> of name
  datatype <a href="#type-ty">ty</a> = <a href="#con-t">T</a> of ann * ty_
  and <a href="#type-ty_">ty_</a> =
      <a href="#con-tvar">TVar</a> of name
    | <a href="#con-tcon">TCon</a> of name
    | <a href="#con-tapp">TApp</a> of ty * ty
    | <a href="#con-tfun">TFun</a> of ty * ty
    | <a href="#con-tlist">TList</a> of ty
    | <a href="#con-ttuple">TTuple</a> of ty list
    | <a href="#con-tparen">TParen</a> of ty
  datatype <a href="#type-pat">pat</a> = <a href="#con-p">P</a> of ann * pat_
  and <a href="#type-pat_">pat_</a> =
      <a href="#con-pvar">PVar</a> of name
    | <a href="#con-pwild">PWild</a>
    | <a href="#con-plit">PLit</a> of lit
    | <a href="#con-pneglit">PNegLit</a> of lit
    | <a href="#con-pcon">PCon</a> of name * pat list
    | <a href="#con-prec">PRec</a> of name * (name * pat) list
    | <a href="#con-ptuple">PTuple</a> of pat list
    | <a href="#con-plist">PList</a> of pat list
    | <a href="#con-pparen">PParen</a> of pat
    | <a href="#con-pas">PAs</a> of name * pat
    | <a href="#con-plazy">PLazy</a> of pat
    | <a href="#con-pnplusk">PNPlusK</a> of name * lit
    | <a href="#con-pseq">PSeq</a> of patitem list
    | <a href="#con-pjux">PJux</a> of pat list
  and <a href="#type-patitem">patitem</a> = <a href="#con-pa">PA</a> of pat | <a href="#con-po">PO</a> of qop
  datatype <a href="#type-exp">exp</a> = <a href="#con-e">E</a> of ann * exp_
  and <a href="#type-exp_">exp_</a> =
      <a href="#con-evar">EVar</a> of name
    | <a href="#con-econ">ECon</a> of name
    | <a href="#con-elit">ELit</a> of lit
    | <a href="#con-eapp">EApp</a> of exp * exp
    | <a href="#con-eseq">ESeq</a> of expitem list
    | <a href="#con-elam">ELam</a> of pat list * exp
    | <a href="#con-elet">ELet</a> of decl list * exp
    | <a href="#con-eif">EIf</a> of exp * exp * exp
    | <a href="#con-ecase">ECase</a> of exp * alt list
    | <a href="#con-edo">EDo</a> of stmt list
    | <a href="#con-etuple">ETuple</a> of exp list
    | <a href="#con-eparen">EParen</a> of exp
    | <a href="#con-elist">EList</a> of exp list
    | <a href="#con-eenum">EEnum</a> of exp * exp option * exp option
    | <a href="#con-ecomp">EComp</a> of exp * stmt list
    | <a href="#con-eleftsec">ELeftSec</a> of exp * qop
    | <a href="#con-erightsec">ERightSec</a> of qop * exp
    | <a href="#con-ereccon">ERecCon</a> of name * (name * exp) list
    | <a href="#con-erecupd">ERecUpd</a> of exp * (name * exp) list
    | <a href="#con-esig">ESig</a> of exp * ty option * ty
  and <a href="#type-expitem">expitem</a> = <a href="#con-ea">EA</a> of exp | <a href="#con-eo">EO</a> of qop | <a href="#con-eneg">ENeg</a>
  and <a href="#type-stmt">stmt</a> = <a href="#con-s">S</a> of ann * stmt_
  and <a href="#type-stmt_">stmt_</a> =
      <a href="#con-sbind">SBind</a> of pat * exp
    | <a href="#con-slet">SLet</a> of decl list
    | <a href="#con-sexp">SExp</a> of exp
  and <a href="#type-alt">alt</a> = <a href="#con-alt">Alt</a> of ann * pat * rhs
  and <a href="#type-rhs">rhs</a> = <a href="#con-rhs">Rhs</a> of ann * rhs_
  and <a href="#type-rhs_">rhs_</a> =
      <a href="#con-plain">Plain</a> of exp * decl list option
    | <a href="#con-guarded">Guarded</a> of guard list * decl list option
  and <a href="#type-guard">guard</a> = <a href="#con-guard">Guard</a> of ann * exp * exp
  and <a href="#type-funlhs">funlhs</a> = <a href="#con-f">F</a> of ann * funlhs_
  and <a href="#type-funlhs_">funlhs_</a> =
      <a href="#con-fprefix">FPrefix</a> of name * pat list
    | <a href="#con-finfix">FInfix</a> of pat * qop * pat
    | <a href="#con-fparen">FParen</a> of funlhs * pat list
  and <a href="#type-decl">decl</a> = <a href="#con-d">D</a> of ann * decl_
  and <a href="#type-decl_">decl_</a> =
      <a href="#con-dsig">DSig</a> of name list * ty option * ty
    | <a href="#con-dfixity">DFixity</a> of fixity * lit option * qop list
    | <a href="#con-dfun">DFun</a> of funlhs * rhs
    | <a href="#con-dpat">DPat</a> of pat * rhs
    | <a href="#con-dtype">DType</a> of name * name list * ty
    | <a href="#con-ddata">DData</a> of ty option * name * name list * constr list * deriv option
    | <a href="#con-dnewtype">DNewtype</a> of ty option * name * name list * constr * deriv option
    | <a href="#con-dclass">DClass</a> of ty option * name * name * decl list option
    | <a href="#con-dinstance">DInstance</a> of ty option * name * ty * decl list option
    | <a href="#con-ddefault">DDefault</a> of ty list
  and <a href="#type-fixity">fixity</a> = <a href="#con-infix">Infix</a> | <a href="#con-infixl">Infixl</a> | <a href="#con-infixr">Infixr</a>
  and <a href="#type-constr">constr</a> = <a href="#con-c">C</a> of ann * constr_
  and <a href="#type-constr_">constr_</a> =
      <a href="#con-cplain">CPlain</a> of name * (bool * ty) list
    | <a href="#con-cinfix">CInfix</a> of (bool * ty) * name * (bool * ty)
    | <a href="#con-crec">CRec</a> of name * field list
  and <a href="#type-field">field</a> = <a href="#con-field">Field</a> of ann * name list * bool * ty
  and <a href="#type-deriv">deriv</a> = <a href="#con-deriv">Deriv</a> of ann * bool * name list
  datatype <a href="#type-entity">entity</a> = <a href="#con-ent">Ent</a> of ann * entity_
  and <a href="#type-entity_">entity_</a> =
      <a href="#con-entvar">EntVar</a> of name
    | <a href="#con-enttype">EntType</a> of name * sub option
    | <a href="#con-entmodule">EntModule</a> of name
  and <a href="#type-sub">sub</a> = <a href="#con-suball">SubAll</a> | <a href="#con-sublist">SubList</a> of name list
  datatype <a href="#type-import">import</a> = <a href="#con-import">Import</a> of ann * {qualified : bool, module : name, as_ : name option, hiding : bool,
                                     spec : entity list option}
  datatype <a href="#type-module">module</a> = <a href="#con-module">Module</a> of ann * {name : name option, exports : entity list option,
                                     imports : import list, decls : decl list}
  val <a href="#val-qname">qname</a> : string * string -&gt; qname
  val <a href="#val-nametext">nameText</a> : qname -&gt; string
  val <a href="#val-issymbolic">isSymbolic</a> : qname -&gt; bool
  val <a href="#val-isspecial">isSpecial</a> : qname -&gt; bool
  val <a href="#val-spanofexp">spanOfExp</a> : exp -&gt; HsSource.span
  val <a href="#val-spanofpat">spanOfPat</a> : pat -&gt; HsSource.span
  val <a href="#val-spanofty">spanOfTy</a> : ty -&gt; HsSource.span
  val <a href="#val-spanofdecl">spanOfDecl</a> : decl -&gt; HsSource.span
end
</pre>

### <a name="type-tok"></a>`tok`

```sml
type tok = {trivia : HsToken.trivium list, start : int, stop : int}
```

A token of the source as a node owns it: the bytes it covers, none
for one of layout's, and the trivia before it.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-tok.trivia"></a>`trivia` | `HsToken.trivium list` |  |
| <a name="fld-tok.start"></a>`start` | `int` |  |
| <a name="fld-tok.stop"></a>`stop` | `int` |  |

### <a name="type-ann"></a>`ann`

```sml
type ann = {span : HsSource.span, toks : tok list}
```

A node's annotation: its span, and its own tokens in the order of the
source.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-ann.span"></a>`span` | `HsSource.span` |  |
| <a name="fld-ann.toks"></a>`toks` | `tok list` |  |

### <a name="val-noann"></a>`noAnn`

```sml
val noAnn : ann
```

The annotation of a node that no source gave, and of every node of a
tree read with annotations off.

### <a name="type-qname"></a>`qname`

```sml
type qname = {qual : string, name : string}
```

A name as written: its qualifier, `""` for none, and the name. The
special constructors are names too: `()`, `[]`, `(,)`, `(,,)` and on,
`(->)`, and `:`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-qname.qual"></a>`qual` | `string` |  |
| <a name="fld-qname.name"></a>`name` | `string` |  |

### <a name="type-name"></a>`name`

```sml
datatype name = Name of ann * qname
```

An identifier or an operator of the source, with its annotation,
whose tokens are the parentheses or backquotes around it, if any,
and the name.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-name"></a>`Name` | `ann * qname` |  |

### <a name="type-lit_"></a>`lit_`

```sml
datatype lit_ =
    LInt of IntInf.int * string
  | LFloat of string
  | LChar of int * string
  | LString of int list * string
```

A literal: its value, and its text as written.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-lint"></a>`LInt` | `IntInf.int * string` | an integer |
| <a name="con-lfloat"></a>`LFloat` | `string` | a floating-point literal, whose value is a rational |
| <a name="con-lchar"></a>`LChar` | `int * string` | a character, by its code point |
| <a name="con-lstring"></a>`LString` | `int list * string` | a string, by its code points |

### <a name="type-lit"></a>`lit`

```sml
datatype lit = Lit of ann * lit_
```

A literal of the source.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-lit"></a>`Lit` | `ann * lit_` |  |

### <a name="type-qop"></a>`qop`

```sml
datatype qop = VarOp of name | ConOp of name
```

An operator where an operator goes: a variable's, `+` or `` `div` ``,
or a constructor's, `:+` or `` `Cons` ``.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-varop"></a>`VarOp` | `name` |  |
| <a name="con-conop"></a>`ConOp` | `name` |  |

### <a name="type-ty"></a>`ty`

```sml
datatype ty = T of ann * ty_
```

A type, a context among them, as written.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-t"></a>`T` | `ann * ty_` |  |

### <a name="type-ty_"></a>`ty_`

```sml
datatype ty_ =
    TVar of name
  | TCon of name
  | TApp of ty * ty
  | TFun of ty * ty
  | TList of ty
  | TTuple of ty list
  | TParen of ty
```

The forms of a type.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-tvar"></a>`TVar` | `name` | a type variable |
| <a name="con-tcon"></a>`TCon` | `name` | a type constructor, `()`, `[]`, `(->)` and the tuples' among them |
| <a name="con-tapp"></a>`TApp` | `ty * ty` | an application |
| <a name="con-tfun"></a>`TFun` | `ty * ty` | `t1 -> t2` |
| <a name="con-tlist"></a>`TList` | `ty` | `[t]` |
| <a name="con-ttuple"></a>`TTuple` | `ty list` | `(t1, ..., tn)` |
| <a name="con-tparen"></a>`TParen` | `ty` | `(t)` |

### <a name="type-pat"></a>`pat`

```sml
datatype pat = P of ann * pat_
```

A pattern.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-p"></a>`P` | `ann * pat_` |  |

### <a name="type-pat_"></a>`pat_`

```sml
datatype pat_ =
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
```

The forms of a pattern.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-pvar"></a>`PVar` | `name` | a variable |
| <a name="con-pwild"></a>`PWild` |  | `_` |
| <a name="con-plit"></a>`PLit` | `lit` | a literal |
| <a name="con-pneglit"></a>`PNegLit` | `lit` | `-` and a numeric literal |
| <a name="con-pcon"></a>`PCon` | `name * pat list` | a constructor and its arguments |
| <a name="con-prec"></a>`PRec` | `name * (name * pat) list` | `C {f1 = p1, ...}` |
| <a name="con-ptuple"></a>`PTuple` | `pat list` | `(p1, ..., pn)` |
| <a name="con-plist"></a>`PList` | `pat list` | `[p1, ..., pn]` |
| <a name="con-pparen"></a>`PParen` | `pat` | `(p)` |
| <a name="con-pas"></a>`PAs` | `name * pat` | `x@p` |
| <a name="con-plazy"></a>`PLazy` | `pat` | `~p` |
| <a name="con-pnplusk"></a>`PNPlusK` | `name * lit` | `n+k` |
| <a name="con-pseq"></a>`PSeq` | `patitem list` | operands and constructor operators, before fixity |
| <a name="con-pjux"></a>`PJux` | `pat list` | juxtaposed patterns, between the parser's two stages only |

### <a name="type-patitem"></a>`patitem`

```sml
datatype patitem = PA of pat | PO of qop
```

An item of a sequence of patterns.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-pa"></a>`PA` | `pat` |  |
| <a name="con-po"></a>`PO` | `qop` |  |

### <a name="type-exp"></a>`exp`

```sml
datatype exp = E of ann * exp_
```

An expression.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-e"></a>`E` | `ann * exp_` |  |

### <a name="type-exp_"></a>`exp_`

```sml
datatype exp_ =
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
```

The forms of an expression.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-evar"></a>`EVar` | `name` | a variable, `(+)` among them |
| <a name="con-econ"></a>`ECon` | `name` | a constructor, `()` and `[]` among them |
| <a name="con-elit"></a>`ELit` | `lit` | a literal |
| <a name="con-eapp"></a>`EApp` | `exp * exp` | an application |
| <a name="con-eseq"></a>`ESeq` | `expitem list` | operands, operators and negations, before fixity |
| <a name="con-elam"></a>`ELam` | `pat list * exp` | `\p1 ... pn -> e` |
| <a name="con-elet"></a>`ELet` | `decl list * exp` | `let ds in e` |
| <a name="con-eif"></a>`EIf` | `exp * exp * exp` | `if e1 then e2 else e3` |
| <a name="con-ecase"></a>`ECase` | `exp * alt list` | `case e of alts` |
| <a name="con-edo"></a>`EDo` | `stmt list` | `do stmts` |
| <a name="con-etuple"></a>`ETuple` | `exp list` | `(e1, ..., en)` |
| <a name="con-eparen"></a>`EParen` | `exp` | `(e)` |
| <a name="con-elist"></a>`EList` | `exp list` | `[e1, ..., en]` |
| <a name="con-eenum"></a>`EEnum` | `exp * exp option * exp option` | `[e1, e2 .. e3]` and its shorter forms |
| <a name="con-ecomp"></a>`EComp` | `exp * stmt list` | `[e \| quals]` |
| <a name="con-eleftsec"></a>`ELeftSec` | `exp * qop` | `(e op)` |
| <a name="con-erightsec"></a>`ERightSec` | `qop * exp` | `(op e)` |
| <a name="con-ereccon"></a>`ERecCon` | `name * (name * exp) list` | `C {f1 = e1, ...}` |
| <a name="con-erecupd"></a>`ERecUpd` | `exp * (name * exp) list` | `e {f1 = e1, ...}` |
| <a name="con-esig"></a>`ESig` | `exp * ty option * ty` | `e :: context => t` |

### <a name="type-expitem"></a>`expitem`

```sml
datatype expitem = EA of exp | EO of qop | ENeg
```

An item of a sequence: an operand, an operator, or `-` as negation.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-ea"></a>`EA` | `exp` |  |
| <a name="con-eo"></a>`EO` | `qop` |  |
| <a name="con-eneg"></a>`ENeg` |  |  |

### <a name="type-stmt"></a>`stmt`

```sml
datatype stmt = S of ann * stmt_
```

A statement of `do`, or a qualifier of a comprehension.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-s"></a>`S` | `ann * stmt_` |  |

### <a name="type-stmt_"></a>`stmt_`

```sml
datatype stmt_ =
    SBind of pat * exp
  | SLet of decl list
  | SExp of exp
```

The forms of a statement.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-sbind"></a>`SBind` | `pat * exp` | `p <- e` |
| <a name="con-slet"></a>`SLet` | `decl list` | `let ds` |
| <a name="con-sexp"></a>`SExp` | `exp` | `e` |

### <a name="type-alt"></a>`alt`

```sml
datatype alt = Alt of ann * pat * rhs
```

An alternative of `case`: `p rhs`, where the right-hand side's
arrow is `->`.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-alt"></a>`Alt` | `ann * pat * rhs` |  |

### <a name="type-rhs"></a>`rhs`

```sml
datatype rhs = Rhs of ann * rhs_
```

A right-hand side: an expression or guards, with a `where`.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-rhs"></a>`Rhs` | `ann * rhs_` |  |

### <a name="type-rhs_"></a>`rhs_`

```sml
datatype rhs_ =
    Plain of exp * decl list option
  | Guarded of guard list * decl list option
```

The forms of a right-hand side.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-plain"></a>`Plain` | `exp * decl list option` | `= e where ds` |
| <a name="con-guarded"></a>`Guarded` | `guard list * decl list option` | `\| g1 = e1 ... where ds` |

### <a name="type-guard"></a>`guard`

```sml
datatype guard = Guard of ann * exp * exp
```

A guard and its expression: `| g = e`.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-guard"></a>`Guard` | `ann * exp * exp` |  |

### <a name="type-funlhs"></a>`funlhs`

```sml
datatype funlhs = F of ann * funlhs_
```

The left-hand side of a function's equation.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-f"></a>`F` | `ann * funlhs_` |  |

### <a name="type-funlhs_"></a>`funlhs_`

```sml
datatype funlhs_ =
    FPrefix of name * pat list
  | FInfix of pat * qop * pat
  | FParen of funlhs * pat list
```

The forms of a left-hand side.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-fprefix"></a>`FPrefix` | `name * pat list` | `f p1 ... pn` |
| <a name="con-finfix"></a>`FInfix` | `pat * qop * pat` | `p1 op p2` |
| <a name="con-fparen"></a>`FParen` | `funlhs * pat list` | `(lhs) p1 ... pn` |

### <a name="type-decl"></a>`decl`

```sml
datatype decl = D of ann * decl_
```

A declaration.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-d"></a>`D` | `ann * decl_` |  |

### <a name="type-decl_"></a>`decl_`

```sml
datatype decl_ =
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
```

The forms of a declaration.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-dsig"></a>`DSig` | `name list * ty option * ty` | `v1, ..., vn :: context => t` |
| <a name="con-dfixity"></a>`DFixity` | `fixity * lit option * qop list` | `infixl 6 +, -` |
| <a name="con-dfun"></a>`DFun` | `funlhs * rhs` | an equation of a function |
| <a name="con-dpat"></a>`DPat` | `pat * rhs` | a pattern binding, a variable's among them |
| <a name="con-dtype"></a>`DType` | `name * name list * ty` | `type T a = t` |
| <a name="con-ddata"></a>`DData` | `ty option * name * name list * constr list * deriv option` | `data` |
| <a name="con-dnewtype"></a>`DNewtype` | `ty option * name * name list * constr * deriv option` | `newtype` |
| <a name="con-dclass"></a>`DClass` | `ty option * name * name * decl list option` | `class context => C a where ds` |
| <a name="con-dinstance"></a>`DInstance` | `ty option * name * ty * decl list option` | `instance context => C t where ds` |
| <a name="con-ddefault"></a>`DDefault` | `ty list` | `default (t1, ..., tn)` |

### <a name="type-fixity"></a>`fixity`

```sml
datatype fixity = Infix | Infixl | Infixr
```

The associativity of a fixity declaration.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-infix"></a>`Infix` |  |  |
| <a name="con-infixl"></a>`Infixl` |  |  |
| <a name="con-infixr"></a>`Infixr` |  |  |

### <a name="type-constr"></a>`constr`

```sml
datatype constr = C of ann * constr_
```

A constructor of `data` or `newtype`.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-c"></a>`C` | `ann * constr_` |  |

### <a name="type-constr_"></a>`constr_`

```sml
datatype constr_ =
    CPlain of name * (bool * ty) list
  | CInfix of (bool * ty) * name * (bool * ty)
  | CRec of name * field list
```

The forms of a constructor.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-cplain"></a>`CPlain` | `name * (bool * ty) list` | `K t1 ... tn`, each argument strict with `!` or not |
| <a name="con-cinfix"></a>`CInfix` | `(bool * ty) * name * (bool * ty)` | `t1 :+ t2` |
| <a name="con-crec"></a>`CRec` | `name * field list` | `K {f1, f2 :: t, ...}` |

### <a name="type-field"></a>`field`

```sml
datatype field = Field of ann * name list * bool * ty
```

The fields of a record constructor that one type has.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-field"></a>`Field` | `ann * name list * bool * ty` |  |

### <a name="type-deriv"></a>`deriv`

```sml
datatype deriv = Deriv of ann * bool * name list
```

A `deriving` clause: whether its classes are in parentheses, and
them.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-deriv"></a>`Deriv` | `ann * bool * name list` |  |

### <a name="type-entity"></a>`entity`

```sml
datatype entity = Ent of ann * entity_
```

What an export or an import names.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-ent"></a>`Ent` | `ann * entity_` |  |

### <a name="type-entity_"></a>`entity_`

```sml
datatype entity_ =
    EntVar of name
  | EntType of name * sub option
  | EntModule of name
```

The forms of an entity.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-entvar"></a>`EntVar` | `name` | a variable |
| <a name="con-enttype"></a>`EntType` | `name * sub option` | a type or a class, with its constructors, fields or methods |
| <a name="con-entmodule"></a>`EntModule` | `name` | `module M`, in an export list |

### <a name="type-sub"></a>`sub`

```sml
datatype sub = SubAll | SubList of name list
```

The constructors or methods an entity names: `(..)`, or a list.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-suball"></a>`SubAll` |  |  |
| <a name="con-sublist"></a>`SubList` | `name list` |  |

### <a name="type-import"></a>`import`

```sml
datatype import = Import of ann * {qualified : bool, module : name, as_ : name option, hiding : bool,
                                   spec : entity list option}
```

An import declaration.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-import"></a>`Import` | `ann * {qualified : bool, module : name, as_ : name option, hiding : bool, spec : entity list option}` |  |

### <a name="type-module"></a>`module`

```sml
datatype module = Module of ann * {name : name option, exports : entity list option,
                                   imports : import list, decls : decl list}
```

A module: its header, if any, its imports and its declarations. The
annotation's last token covers no byte and holds the trivia at the end
of the file.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-module"></a>`Module` | `ann * {name : name option, exports : entity list option, imports : import list, decls : decl list}` |  |

### <a name="val-qname"></a>`qname`

```sml
val qname : string * string -> qname
```

`qname (qual, name)` is the name `name` qualified by `qual`, `""` for
none.

### <a name="val-nametext"></a>`nameText`

```sml
val nameText : qname -> string
```

`nameText q` is the name as the source writes it in a variable's
place, qualified: M.x for `x` of `M`, or `+`.

### <a name="val-issymbolic"></a>`isSymbolic`

```sml
val isSymbolic : qname -> bool
```

`isSymbolic q` is whether the name of `q` is an operator's rather
than an identifier's: its first character is a symbol or `:`.

The special constructors but `:` are not.

### <a name="val-isspecial"></a>`isSpecial`

```sml
val isSpecial : qname -> bool
```

`isSpecial q` is whether `q` is one of the special constructors that
are written with brackets: `()`, `[]`, the tuples', `(->)`.

### <a name="val-spanofexp"></a><a name="val-spanofpat"></a><a name="val-spanofty"></a><a name="val-spanofdecl"></a>`spanOfExp`, `spanOfPat`, `spanOfTy`, `spanOfDecl`

```sml
val spanOfExp : exp -> HsSource.span
val spanOfPat : pat -> HsSource.span
val spanOfTy : ty -> HsSource.span
val spanOfDecl : decl -> HsSource.span
```

`spanOfExp e`, `spanOfPat p`, `spanOfTy t` and `spanOfDecl d` are the
spans of the nodes.

---

<sub>Generated by runedoc from lib/language/haskell/ast\_sig.sml; do not edit.</sub>
