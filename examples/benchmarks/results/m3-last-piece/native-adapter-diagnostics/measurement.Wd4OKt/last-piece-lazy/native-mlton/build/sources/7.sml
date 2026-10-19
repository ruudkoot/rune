functor LastPieceCheckFn (K : sig
  type tree
  val solve : int -> tree
  val render : tree -> (string -> unit) -> int
end) =
struct
  fun run remaining path =
    let val input=BinIO.openIn path val count=ref 0
        fun emit text =
          let fun loop i=if i=String.size text then()else(case BinIO.input1 input of
                  SOME value=>if Word8.toInt value=Char.ord(String.sub(text,i))then(count:= !count+1;loop(i+1))
                    else raise Fail "incorrect result: Last Piece output byte differs"
                |NONE=>raise Fail "incorrect result: extra Last Piece output")
          in loop 0 end
        val solutions=K.render(K.solve remaining)emit handle ex=>(BinIO.closeIn input;raise ex)
        val extra=BinIO.input1 input val _=BinIO.closeIn input
    in if Option.isSome extra then raise Fail "incorrect result: short Last Piece output"else(solutions,!count)end
end
