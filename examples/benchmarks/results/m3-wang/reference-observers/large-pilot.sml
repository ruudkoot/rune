structure LazyWang = BenchWangFn (BenchNeed)
structure StrictWang = BenchWangFn (BenchStrict)
structure LazyDriver = BenchWangDriverFn (LazyWang)
structure StrictDriver = BenchWangDriverFn (StrictWang)
structure Pilot =
struct
  val _ = print ("PASS lazy large " ^ LazyDriver.run ["150","500"] ^ "\n")
  val _ = print ("PASS strict large " ^ StrictDriver.run ["150","500"] ^ "\n")
end
