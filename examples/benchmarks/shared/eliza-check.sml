functor ElizaCheckFn (K : sig
  type text
  val conversation : string list -> int -> text
  val app : (char -> unit) -> text -> unit
end) =
struct
  fun run lines prefix path =
    let val input = BinIO.openIn path
        val count = ref 0
        fun emit c = case BinIO.input1 input of SOME value =>
              if Word8.toInt value = Char.ord c then count := !count + 1
              else raise Fail "incorrect result: Eliza response byte differs"
          | NONE => raise Fail "incorrect result: extra Eliza response"
        val _ = K.app emit (K.conversation lines prefix)
                handle ex => (BinIO.closeIn input; raise ex)
        val extra = BinIO.input1 input
        val _ = BinIO.closeIn input
    in if Option.isSome extra then raise Fail "incorrect result: short Eliza response"
       else !count
    end
end
