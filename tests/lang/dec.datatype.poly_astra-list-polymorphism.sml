val empty = []
val ints = 1 :: empty
val bools = true :: empty
val [id] = [fn x => x]
val a = id 42
val b = id true
val ids = (fn x => x) :: nil
val first = fn xs => case xs of f :: _ => f | [] => fn x => x
val _ = if b andalso first ids false = false andalso ints = [1] andalso bools = [true]
        then print (Int.toString (first ids a) ^ "\n") else print "bad\n"
val aliases = nil
val aliases = [1]
val _ = if aliases = [1] then print "alias\n" else print "bad\n"
