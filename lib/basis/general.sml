(* General: the exceptions and combinators of the initial basis as a structure. *)
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
