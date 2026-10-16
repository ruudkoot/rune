structure IntegerWord64Probe =
struct
  fun line () = valOf (TextIO.inputLine TextIO.stdIn)
  val minimum = valOf (Word64.fromString (line ()))
  val maximum = valOf (Word64.fromString (line ()))
  val _ = print ("constant-sub " ^ Word64.toString (Word64.- (0wx8000000000000000, 0w1)) ^ "\n")
  val _ = print ("dynamic-sub " ^ Word64.toString (Word64.- (minimum, 0w1)) ^ "\n")
  val _ = print ("constant-mul " ^ Word64.toString (Word64.* (0wx7fffffffffffffff, 0w2)) ^ "\n")
  val _ = print ("dynamic-mul " ^ Word64.toString (Word64.* (maximum, 0w2)) ^ "\n")
  val _ = T.check ("integer/runtime-sub-wrap", fn () => Word64.toString (Word64.- (minimum, 0w1)) = "7FFFFFFFFFFFFFFF")
  val _ = T.check ("integer/runtime-multiply-wrap", fn () => Word64.toString (Word64.* (maximum, 0w2)) = "FFFFFFFFFFFFFFFE")
end
