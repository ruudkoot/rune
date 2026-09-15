(* The parser produces this small, syntax-directed expression tree. *)
signature RUNE_AST =
sig
  datatype binop = Add | Sub | Mul | Div | Eq | Ne | Lt | Le | Gt | Ge
  datatype expr =
      EInt of int
    | EBool of bool
    | EVar of string
    | EBin of binop * expr * expr
    | EIf of expr * expr * expr
    | ELet of string * expr * expr
    | ESeq of expr * expr
end

structure RuneAst : RUNE_AST =
struct
  datatype binop = Add | Sub | Mul | Div | Eq | Ne | Lt | Le | Gt | Ge
  datatype expr =
      EInt of int
    | EBool of bool
    | EVar of string
    | EBin of binop * expr * expr
    | EIf of expr * expr * expr
    | ELet of string * expr * expr
    | ESeq of expr * expr
end
