module R = Rune_reference_random
let () =
 let s=R.State.copy R.default in
 let a=R.State.bits s in let b=R.State.bits s in
 let r=R.State.float (R.State.copy R.default) 1.0 in
 Printf.printf "%d %d %.17g %.17g %.17g\n" a b r
  ((float a /. 1073741824.0 +. float b) /. 1073741824.0)
  ((float b /. 1073741824.0 +. float a) /. 1073741824.0)
