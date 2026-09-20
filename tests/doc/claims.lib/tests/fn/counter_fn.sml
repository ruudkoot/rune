functor TestCounterFn (structure C : sig type t val next : t -> t end val name : string) =
struct
  fun lab s = name ^ "." ^ s
  fun table (label, cases) = List.app (fn c => T.check (label ^ c, fn () => true)) cases
  val () = T.check (lab "next/moves", fn () => true)
  val () = table (lab "next/", ["once", "twice"])
end
