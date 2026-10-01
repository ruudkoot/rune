structure MeasurementTests =
struct
  fun check label value = T.check (label, fn () => value)
  fun fails f = (f (); false) handle Fail _ => true
  fun close (a,b) = Real.abs(a-b) < 0.000000001
  val _ = check "measurement/median-even" (close (BenchReport.quantile [1.0,2.0,4.0,8.0] 0.5,3.0))
  val _ = check "measurement/q1" (close (BenchReport.quantile [1.0,2.0,4.0,8.0] 0.25,1.75))
  val _ = check "measurement/q3" (close (BenchReport.quantile [1.0,2.0,4.0,8.0] 0.75,5.0))
  val _ = check "measurement/singleton" (close (BenchReport.quantile [7.0] 0.25,7.0))
  val _ = check "measurement/reject-negative-time"
    (fails (fn () => ignore (BenchReport.parse "tak\tsmoke\trune\tO2\tfresh\t1\t1\tpass\t~1.0\t0\t0\t0\t-\t-\t-\trun")))
  val base : BenchCounts.row = {name="tak",profile="smoke",config="rune",level="O2",instructions=100,bytes=80,objects=10}
  val native : BenchCounts.row = {name="tak",profile="smoke",config="rune:opt",level="O2",instructions=100,bytes=80,objects=10}
  val regs : BenchCounts.row = {name="tak",profile="smoke",config="rune:new",level="O2",instructions=50,bytes=80,objects=10}
  val badInst : BenchCounts.row = {name="tak",profile="smoke",config="rune:opt",level="O2",instructions=99,bytes=80,objects=10}
  val badAlloc : BenchCounts.row = {name="tak",profile="smoke",config="rune:new",level="O2",instructions=50,bytes=81,objects=10}
  val tooLow : BenchCounts.row = {name="tak",profile="smoke",config="rune",level="O2",instructions=99,bytes=80,objects=10}
  val _ = check "measurement/models" (not (fails (fn () => BenchCounts.compare [base,native,regs])))
  val _ = check "measurement/instruction-mismatch" (fails (fn () => BenchCounts.compare [base,badInst]))
  val _ = check "measurement/allocation-mismatch" (fails (fn () => BenchCounts.compare [base,badAlloc]))
  val _ = check "measurement/budget-exceeded" (fails (fn () => BenchCounts.verify [base] [tooLow]))
  val _ = check "measurement/count-not-a-prefix" (fails (fn () => ignore (BenchCounts.number "123x")))
end
