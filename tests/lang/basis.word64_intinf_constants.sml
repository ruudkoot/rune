structure Word64IntInfConstants =
struct
  val all = Word64.notb 0w0
  val () = print(Bool.toString(IntInf.toString(Word64.toLargeInt all)="18446744073709551615") ^ "\n")
  val () = print(Bool.toString(Word64.toLargeIntX all = IntInf.fromInt (~1)) ^ "\n")
  val () = print(Bool.toString(Word64.fromLargeInt(valOf(IntInf.fromString "18446744073709551616"))=0w0) ^ "\n")
end
