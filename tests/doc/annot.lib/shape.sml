(* Shapes.

   Area: Tests *)
signature SHAPE =
sig
  (* A shape. *)
  datatype shape
    = Circle of int   (* a circle, by its radius *)
    | Square of int   (* a square, by its side *)

  (* `area s` is the area of `s`, rounded down. *)
  val area : shape -> int

  (* `scale (s, k)` is `s`, `k` times as large. *)
  val scale : shape * int -> shape

  (* `name s` is what `s` is called. *)
  val name : shape -> string

  (* `grow s` is `scale (s, 2)`. *)
  val grow : shape -> shape
end

(* Implements: SHAPE *)
structure Shape =
struct
  datatype shape = Circle of int | Square of int
  fun area (Circle r) = 3 * r * r
    | area (Square a) = a * a
  fun scale (Circle r, k) = Circle (r * k)
    | scale (Square a, k) = Square (a * k)
  fun name (Circle _) = "circle"
    | name (Square _) = "square"
  fun grow s = scale (s, 2)
end
