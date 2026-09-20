structure TestUnit =
struct
  val () = T.check ("Unit.it/is-unit", fn () => true)
  val () = T.check ("Unit.extra/is-unit", fn () => true)
end
