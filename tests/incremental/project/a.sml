(* the project of the cache's scenarios (tests/incremental/SCENARIOS.md):
   a signature, a structure with a datatype and an exception *)
signature SHAPE =
sig
  type t
  val area : t -> int
end

structure A =
struct
  datatype shape = Square of int | Rect of int * int
  exception Bad of string
  fun area (Square n) = n * n
    | area (Rect (w, h)) = w * h
  val unused = 0
end
