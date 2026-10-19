functor PackedNucleotideCheckFn (K : sig val run : string -> (string -> unit) -> unit end) =
struct
  fun run path reference =
    let val input = BinIO.openIn reference val count = ref 0
        fun emit text =
          let fun loop i = if i = String.size text then () else
                (case BinIO.input1 input of
                   SOME byte => if Word8.toInt byte = Char.ord (String.sub (text, i))
                     then (count := !count + 1; loop (i + 1))
                     else raise Fail "incorrect result: nucleotide text differs"
                 | NONE => raise Fail "incorrect result: extra nucleotide text")
          in loop 0 end
        val _ = K.run path emit handle ex => (BinIO.closeIn input; raise ex)
        val extra = BinIO.input1 input val _ = BinIO.closeIn input
    in if Option.isSome extra then raise Fail "incorrect result: short nucleotide output" else !count end
end
