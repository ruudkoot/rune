structure NeedExact=BenchExactRealsFn(BenchNeed)
structure StrictExact=BenchExactRealsFn(BenchStrict)
structure Pilot =
struct
  val _=print("NEED "^NeedExact.run 60^"\n")
  val _=print("STRICT "^StrictExact.run 60^"\n")
end
