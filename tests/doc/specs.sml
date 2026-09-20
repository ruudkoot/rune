(* Every kind of specification, and the derived forms the parser rewrites. *)
signature ORDERED =
sig
  type t
  val compare : t * t -> order
end

signature SPECS =
sig
  type 'a seq
  eqtype key
  type pair = key * int and 'a box = {contents : 'a, tag : key}
  datatype 'a tree = Leaf (* nothing *) | Node of 'a tree * 'a * 'a tree
  datatype shape =
      Circle of {centre : real * real, radius : real}
    | Box of {corner : real * real,   (* lower left *)
              width : real,
              height : real}
  datatype order = datatype order
  exception Empty
  exception Bad of {line : int, why : string} and Worse of string

  val empty : 'a seq
  val insert : key * 'a -> 'a seq -> 'a seq
  and remove : key -> 'a seq -> 'a seq
  val op @@ : 'a seq * 'a seq -> 'a seq
  val fold : ({key : key, value : 'a} * 'b -> 'b) -> 'b -> 'a seq -> 'b
  val find : ('a -> bool) (* the test *) -> 'a seq -> 'a option

  structure Key : ORDERED where type t = key
  structure Limits : sig val maxLen : int  val minLen : int end
  structure A : ORDERED and B : ORDERED
  sharing type A.t = B.t

  include ORDERED
  include ORDERED where type t = key
end

signature INCLUDES =
sig
  include ORDERED SPECS
  include sig val extra : int end
end

signature RENAMED = ORDERED where type t = int
