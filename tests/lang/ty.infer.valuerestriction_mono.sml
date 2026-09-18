(* an expansive binding stays monomorphic; it can still be used at one type
   within the declaration that determines it *)
local
  val r = ref []
in
  val () = r := [1]
  val n = hd (!r)
end
val () = print (Int.toString n ^ "\n")
local
  val f = (fn x => x) (fn y => y)
in
  val three = f 3
end
val () = print (Int.toString three ^ "\n")
