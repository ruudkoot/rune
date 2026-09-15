fun grow (n, f) =
  if n = 0 then f 0
  else grow (n - 1, fn x => f (x + 1))
val _ = grow (10000, fn x => x)
