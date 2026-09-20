structure TestUnit =
struct
  val () = T.check ("Unit.it/is-unit", fn () => true)
  val () = T.check ("Unit.extra/is-unit", fn () => true)
  val () = List.app (fn n => T.check ("Unit.again/" ^ n, fn () => true)) ["made-here"]
end
