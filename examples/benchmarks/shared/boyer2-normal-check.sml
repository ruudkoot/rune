functor BoyerTwoNormalCheckFn (K : sig type term val normal : int -> term val write : term -> (string -> unit) -> unit end) =
struct
  fun run i path =
    let val input = BinIO.openIn path
        fun emit text =
          let fun loop k = if k = String.size text then () else
                (case BinIO.input1 input of SOME value =>
                   if Word8.toInt value = Char.ord (String.sub (text, k)) then loop (k + 1)
                   else raise Fail "incorrect result: Boyer2 normal form differs"
                 | NONE => raise Fail "incorrect result: extra Boyer2 normal form")
          in loop 0 end
        val _ = (K.write (K.normal i) emit; emit "\n") handle ex => (BinIO.closeIn input; raise ex)
        val extra = BinIO.input1 input val _ = BinIO.closeIn input
    in if Option.isSome extra then raise Fail "incorrect result: short Boyer2 normal form" else () end
end
