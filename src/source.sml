structure Source =
struct
  type pos = {line : int, column : int}
  val start : pos = {line = 1, column = 1}
  exception Error of pos * string * string
  fun fail pos category message = raise Error (pos, category, message)
  val warnings = ref ([] : (pos * string) list)
  fun warn pos message = warnings := (pos,message) :: !warnings
  val maxSource = 1048576
  val maxCount = 65536
  val maxString = 1048576
  val minInt = valOf (IntInf.fromString "~2147483648")
  val maxInt = valOf (IntInf.fromString "2147483647")
  val modulus = valOf (IntInf.fromString "4294967296")
  fun intRange p n =
    if n < minInt orelse n > maxInt then
      fail p "range" "integer literal is outside Rune's signed 32-bit range"
    else n
end
