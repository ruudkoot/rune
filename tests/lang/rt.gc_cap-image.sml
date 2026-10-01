val phase = Runtime.save "tests/out/rt.gc_cap-image.img"
val xs = List.tabulate (100, fn i => i)
val () = Runtime.collect ()
val () = print ((if #heapSize (Runtime.stats ()) <= 65536 then "limited:" else "unlimited:")
                ^ Int.toString (List.length xs) ^ "\n")
