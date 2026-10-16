structure IntegerNeed = BenchIntegerFn (BenchNeed)
structure IntegerStrict = BenchIntegerFn (BenchStrict)
structure Pilot =
struct
  val strict = CommandLine.arguments () = ["strict"]
  val result = if strict then IntegerStrict.run (~2100000000, 4500001, 2100000000)
               else IntegerNeed.run (~2100000000, 4500001, 2100000000)
  val _ = IntegerCheck.validate result "tests/out/benchmarks/integer-originals/normal.expected"
  val _ = print "PASS complete normal 28 digests\n"
end
