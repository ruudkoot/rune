(* General: option, order, common exceptions and combinators.
   NOTE: the VM builds option values directly, so NONE must have tag 0 and
   SOME tag 1 (declaration order matters). *)

datatype 'a option = NONE | SOME of 'a
datatype order = LESS | EQUAL | GREATER

exception Fail of string
exception Option
exception Empty
exception Span
exception Unordered

fun not true = false
  | not false = true

fun ignore _ = ()

fun (f o g) x = f (g x)

fun a before b = a

fun getOpt (SOME v, _) = v
  | getOpt (NONE, d) = d

fun isSome (SOME _) = true
  | isSome NONE = false

fun valOf (SOME v) = v
  | valOf NONE = raise Option

val print = _prim "print" : string -> unit

structure General =
struct
  type unit = unit
  type exn = exn
  exception Bind = Bind
  exception Match = Match
  exception Chr = Chr
  exception Div = Div
  exception Domain = Domain
  exception Fail = Fail
  exception Overflow = Overflow
  exception Size = Size
  exception Span = Span
  exception Subscript = Subscript
  datatype order = datatype order
  val ! = !
  val op := = op :=
  val op o = op o
  val op before = op before
  val ignore = ignore
end
