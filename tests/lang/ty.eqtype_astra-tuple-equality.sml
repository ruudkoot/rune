fun same (x,y) = x = y
val _ = if same ((1,(true,"x")),(1,(true,"x")))
           andalso same ((),()) andalso same ("a","a")
           andalso (1,2) <> (1,3)
        then print "equal\n" else ()
