(* A virtual functor's signatures (the build-system roadmap's M21) *)
signature ORD =
sig
  type t
  val compare : t * t -> order
  val show : t -> string
end

signature SET =
sig
  type elem
  type set
  exception Absent of elem
  val empty : set
  val add : set * elem -> set
  val size : set -> int
  val remove : set * elem -> set
  val elems : set -> elem list
end
