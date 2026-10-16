structure NeedExact=BenchExactRealsFn(BenchNeed)
structure StrictExact=BenchExactRealsFn(BenchStrict)
structure Pilot =
struct
  val result=case CommandLine.arguments()of
      ["lazy",n]=>NeedExact.run(valOf(Int.fromString n))
    |["strict",n]=>StrictExact.run(valOf(Int.fromString n))
    |_=>raise Fail "exact-real pilot arguments"
  val _=print(result^"\n")
end
