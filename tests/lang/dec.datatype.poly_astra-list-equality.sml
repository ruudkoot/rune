fun same xs ys = xs = ys
datatype t = C of int list
val _ = if same [C [1,2],C []] [C (1::2::nil),C nil]
           andalso same [[(1,true)],[]] [[(1,true)],nil]
           andalso [1,2] <> [1,3] andalso [1] <> [1,2]
           andalso ["a\000b"] = ["a\000b"]
        then print "equal\n" else print "bad\n"
