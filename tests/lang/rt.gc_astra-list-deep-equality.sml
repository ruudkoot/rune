fun build n xs = if n = 0 then xs else build (n-1) (n :: xs)
val a = build 1000 []
val b = build 1000 []
val _ = if a = b then print "equal\n" else print "bad\n"
