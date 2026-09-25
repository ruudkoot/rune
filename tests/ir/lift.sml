(* dump: --passes=shake,lift,workers,simplify --dump-after=simplify *)
(* Lambda lifting: go, local to sum, never escapes, so it is a function of
   the top level (and a worker of it, g1, takes its pair as two); m, local
   to scale, captured k, so the lifted m (g3) takes k first, and every call
   passes it; keep escapes -- scale2 returns it -- and captures k, so it
   stays a closure; the fn of addTwo escapes too, into twice, but captures
   nothing, so it is lifted all the same, a global whose closure is made
   once (a static closure), and passed as that global. *)
fun sum (xs : int list) =
  let
    fun go ([], acc) = acc
      | go (x :: rest, acc) = go (rest, acc + x)
  in go (xs, 0) end
fun scale k xs =
  let fun m [] = [] | m (x :: r) = k * x :: m r
  in m xs end
fun scale2 k =
  let fun keep x = k * x
  in keep end
fun twice f (x : int) = f (f x)
fun addTwo n = twice (fn y => y + 1) n
val r = (sum [1, 2], scale 2 [3], scale2 4 5, addTwo 6)
