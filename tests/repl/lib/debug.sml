datatype shape = Circle of real | Square of int
fun area s =
  case s of
    Circle r => 3.0 * r * r
  | Square n => real (n * n)
fun total shapes =
  let
    val label = "total"
    val parts = map area shapes
    val sum = foldl op+ 0.0 parts
  in
    (label, sum)
  end
fun adder k =
  let fun add x =
        x + k
  in add end
fun twice x =
  let val x = x * 2
      val x = x + 1
  in x
  end
fun fail n = if n = 0 then raise Fail "none left" else fail (n - 1)
