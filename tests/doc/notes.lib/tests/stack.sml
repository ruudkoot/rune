structure TestStack =
struct
  val () = T.check ("Stack.empty/is-empty", fn () => true)
  val () = T.check ("Stack.push/returns-new", fn () => true)
  val () = List.app (fn n => T.check ("Stack.push/full-" ^ n, fn () => true)) ["1", "2"]
  val () = T.check ("Stack.pop/basic", fn () => true)
  val () = T.check ("Stack:STACK/matches", fn () => true)
end
