val _ = if 1 < 2 andalso 2 <= 2 andalso 3 > 2 andalso 3 >= 3 andalso 3 <> 4
        andalso "abc" = ("a" ^ "bc") andalso () = () andalso not false = true
        then print "yes\n" else print "bad\n"
