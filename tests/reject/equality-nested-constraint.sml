fun same (x,y) = (x,1) = (y,1)
val bad = same (fn x => x, fn x => x)
