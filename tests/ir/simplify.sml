(* dump: --dump-after=simplify *)
(* The simplifier: y is a; the tuple p is known, so #1 p is y and #2 p is
   b, and unused goes; 2 + 3 is 5, so the if is known true; SOME made here
   has a known tag, so the match's other rule and its failure go; sq is
   called once, where it is made, so its body is put there; the sum that
   would overflow is left to raise; and in k, h only calls inc with its
   parameter, so it is inc (eta). *)
datatype 'a opt = NONE | SOME of 'a
fun f (a, b) =
  let
    val y = a
    val p = (y, b)
    val unused = (b, b)
    val k = 2 + 3
    fun sq x = x * x
  in
    case SOME (#1 p) of
      SOME z => if k > 4 then sq z + #2 p else 0
    | NONE => 1
  end
fun g () = 9223372036854775807 + 1
fun twice t x = t (t x)
fun inc n = n + 1
fun k y =
  let fun h z = inc z
  in twice h y end
val result = (f (1, 2), g, k 3)
