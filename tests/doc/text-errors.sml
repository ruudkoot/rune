(* Doc comments that are wrong: each paragraph below is an error.

   Implements: TEXT *)
signature WRONG =
sig
  (* A backquote `without a partner. *)
  type a

  (* Raises: Subscript if it is not in backquotes. *)
  val b : int -> int

  (* Status: sometimes *)
  type c

  (* Reading: no id in backquotes. *)
  type d

  (* Reading (the suite agrees): `X.y/z`. An unknown modifier. *)
  type e

  (* Raises: `Subscript` on a type. *)
  type f

  (* Pinned by: `X.y/z` *)
  type g

  (* Example: *)
  type h

  (* `take (l, i, j)` has a tuple of three. *)
  val take : 'a list * int -> 'a list

  (* `nth l i` is curried where the type is not. *)
  val nth : 'a list * int -> 'a

  (* `make {size, colour}` has the wrong labels. *)
  val make : {size : int, fill : char} -> int

  (* `apply (f, x)` has a tuple where the type has a function. *)
  val apply : (int -> int) -> int
end
