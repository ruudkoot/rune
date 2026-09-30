val _ = if true orelse false andalso false then print "a" else print "bad"
val _ = if false andalso if true then true else false orelse true then print "bad" else print "b\n"
