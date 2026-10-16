structure BenchMandelTwoPoint =
struct
  structure F = BenchMandelSingle
  val deltaP = F.divide (F.sub (0.75, ~2.25), 199.0)
  val deltaQ = F.divide (F.sub (1.5, ~1.5), 199.0)
  fun p x = F.add (~2.25, F.mul (F.round (Real.fromInt x), deltaP))
  fun q y = F.add (~1.5, F.mul (F.round (Real.fromInt y), deltaQ))
  fun next (p, q, x, y) =
    let val nx = F.add (F.sub (F.mul (x, x), F.mul (y, y)), p)
        val ny = F.add (F.mul (F.mul (2.0, x), y), q)
        val radius = F.add (F.mul (nx, nx), F.mul (ny, ny))
    in (nx, ny, radius) end
  fun colour (x, y) =
    let val p = p x val q = q y
        fun loop k x y =
          if k + 1 = 26 then 0 else
          let val (nx, ny, radius) = next (p, q, x, y)
          in if radius > 20.0 then k + 1 else loop (k + 1) nx ny end
    in loop 0 0.0 0.0 end
end
