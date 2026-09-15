fun same x y = x = y
val bad = same (fn x => x) (fn x => x)
