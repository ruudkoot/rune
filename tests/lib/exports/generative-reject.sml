structure A = Make (struct val delta = 1 end)
structure B = Make (struct val delta = 1 end)
val bad : A.Fresh.t = B.Fresh.C
