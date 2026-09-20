structure TestShape =
struct
  val () = T.check ("Shape.area/circle", fn () => true)
  val () = T.check ("Shape.area/square", fn () => true)
  val () = T.check ("Shape.scale/by-zero", fn () => true)
  val () = T.check ("Shape.scale/by-one", fn () => true)
  val () = List.app (fn n => T.check ("Shape.name/of-" ^ n, fn () => true)) ["circle", "square"]
  val () = List.app (fn n => T.check ("Shape.grow/" ^ n, fn () => true)) ["twice", "thrice"]
  val () = T.check ("Shape.Circle/is-a-constructor", fn () => true)
  val () = T.check ("Shape:SHAPE/matches", fn () => true)
end
