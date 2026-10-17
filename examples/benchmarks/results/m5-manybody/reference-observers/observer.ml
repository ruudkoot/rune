let () =
 Array.iter (fun (b:Kernel.planet) ->
   Printf.printf "%.17g %.17g %.17g %.17g %.17g %.17g %.17g\n" b.x b.y b.z b.vx b.vy b.vz b.mass) Kernel.bodies
