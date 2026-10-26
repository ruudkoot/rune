(* A dynamic module's signature, which the module and the program that
   loads it are compiled against (tests/runner/compilermutants.sml: the
   corpus's dynamic module; docs/units.md, Dynamic modules). *)
signature SHAPE =
sig
  type t
  datatype kind = Round | Square of int
  exception Bad of int
  val make : int -> t
  val area : t -> int
  val kindOf : t -> kind
  val name : string
  val twice : 'a -> 'a * 'a
end
