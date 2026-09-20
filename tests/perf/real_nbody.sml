(* Real: a two-body orbit integrated with the leapfrog method. *)
fun step (0, x, y, vx, vy) = (x, y, vx, vy)
  | step (k, x, y, vx, vy) =
    let
      val dt = 0.001
      val r2 = x * x + y * y
      val r3 = r2 * Math.sqrt r2
      val vx = vx - dt * x / r3
      val vy = vy - dt * y / r3
    in step (k - 1, x + dt * vx, y + dt * vy, vx, vy) end
val (x, y, vx, vy) = step (20000, 1.0, 0.0, 0.0, 1.0)
val energy = 0.5 * (vx * vx + vy * vy) - 1.0 / Math.sqrt (x * x + y * y)
val () = print (Int.toString (Real.round (energy * 1000000.0)) ^ " " ^ Int.toString (Real.round (x * 1000.0)) ^ "\n")
