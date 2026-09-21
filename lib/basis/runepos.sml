(* The positions of the readers and the writers of text, made abstract where
   they are declared, because the specification says of `TextPrimIO.pos` only
   that it is a type. (`BinPrimIO.pos` is `Position.int`, which the
   specification does require, so bytes need nothing of this.)

   A position is an offset in the file underneath, which is what the library
   turns into and out of; a program has only `compare`, and gets its
   positions from `getPosIn`, `getPosOut` and the readers. `WideTextPrimIO`
   has a second type of its own: nothing says that a position in a stream of
   wide characters is one of a stream of characters. *)
structure RuneTextPos :>
sig
  eqtype pos
  val compare : pos * pos -> order
  val fromInt : int -> pos
  val toInt : pos -> int
  val advance : pos * int -> pos
end =
struct
  type pos = Position.int
  val compare = Position.compare
  val fromInt = Position.fromInt
  val toInt = Position.toInt
  fun advance (p, n) = Position.+ (p, Position.fromInt n)
end

structure RuneWideTextPos :>
sig
  eqtype pos
  val compare : pos * pos -> order
  val fromInt : int -> pos
  val toInt : pos -> int
  val advance : pos * int -> pos
end =
struct
  type pos = Position.int
  val compare = Position.compare
  val fromInt = Position.fromInt
  val toInt = Position.toInt
  fun advance (p, n) = Position.+ (p, Position.fromInt n)
end
