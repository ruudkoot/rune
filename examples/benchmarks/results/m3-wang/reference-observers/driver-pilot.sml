structure LazyWang = BenchWangFn (BenchNeed)
structure StrictWang = BenchWangFn (BenchStrict)
structure LazyDriver = BenchWangDriverFn (LazyWang)
structure StrictDriver = BenchWangDriverFn (StrictWang)
structure Pilot =
struct
  val _ = print ("PASS lazy normal " ^ LazyDriver.run ["80","500"] ^ "\n")
  val _ = print ("PASS strict normal " ^ StrictDriver.run ["80","500"] ^ "\n")
end
