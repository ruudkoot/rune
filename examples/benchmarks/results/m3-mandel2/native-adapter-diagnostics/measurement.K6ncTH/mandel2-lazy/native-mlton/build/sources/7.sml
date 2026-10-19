functor MandelTreeCheckFn (K : sig
  type tree
  val build : int * int -> int * int -> tree
  val write : int -> (string -> unit) -> tree -> int
end) =
struct
  fun run width path =
    let val input = TextIO.openIn path
        fun emit row = case TextIO.inputLine input of
            SOME expected => if row = expected then () else raise Fail "incorrect result: Mandel tree row differs"
          | NONE => raise Fail "incorrect result: extra Mandel tree row"
        val count = K.write width emit (K.build (0, 0) (width, width div 2))
          handle ex => (TextIO.closeIn input; raise ex)
        val extra = TextIO.inputLine input val _ = TextIO.closeIn input
    in if Option.isSome extra then raise Fail "incorrect result: short Mandel tree output" else count end
end
