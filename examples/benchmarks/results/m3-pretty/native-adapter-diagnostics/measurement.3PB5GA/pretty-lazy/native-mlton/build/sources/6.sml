functor PrettyCheckFn (K : sig val run : int -> int -> (char -> unit) -> unit end) =
struct
  fun run width words path =
    let val input = BinIO.openIn path val count = ref 0
        fun emit c = case BinIO.input1 input of
            SOME value => if Word8.toInt value = Char.ord c then count := !count + 1
              else raise Fail "incorrect result: pretty output byte differs"
          | NONE => raise Fail "incorrect result: extra pretty output"
        val _ = K.run width words emit handle ex => (BinIO.closeIn input; raise ex)
        val extra = BinIO.input1 input val _ = BinIO.closeIn input
    in if Option.isSome extra then raise Fail "incorrect result: short pretty output" else !count end
end
