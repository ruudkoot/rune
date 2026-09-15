val _ = if "x\000y" = "x\000y" andalso "x\000y" <> "x"
        then print ("a\000" ^ "b\n") else print "bad"
