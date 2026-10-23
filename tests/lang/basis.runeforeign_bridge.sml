val () = if RuneForeign.live () = 0w0 then () else raise Fail "foreign registry is not empty"
val () = if RuneForeign.available () then () else
  ((ignore(RuneForeign.openLibrary "unavailable");raise Fail "missing availability error") handle RuneForeign.Error _ => ())
val () = print "foreign bridge descriptors are portable\n"
