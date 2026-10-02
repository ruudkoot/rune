structure QueensTests =
struct
  val calls = ref 0
  val value = BenchLazy.delay (fn () => (calls := !calls+1; 17))
  val _ = T.check ("lazy/not-demanded",fn () => !calls = 0)
  val _ = T.check ("lazy/shared-value",fn () => BenchLazy.force value = 17 andalso BenchLazy.force value = 17 andalso !calls = 1)
  exception Broken
  val errors = ref 0
  val failure : int BenchLazy.delay = BenchLazy.delay (fn () => (errors := !errors+1; raise Broken))
  fun broken () = (BenchLazy.force failure; false) handle Broken => true
  val _ = T.check ("lazy/shared-exception",fn () => broken () andalso broken () andalso !errors = 1)
  val recursive : int BenchLazy.delay = ref BenchLazy.Evaluating
  val _ = T.check ("lazy/reentry",fn () => ((BenchLazy.force recursive; false) handle Fail _ => true))
  val solutions = [1,0,0,2,10,4,40,92,352,724]
  val _ = List.app (fn (i,want) =>
    T.check ("queens/" ^ Int.toString (i+1),fn () =>
      BenchQueens.lazy (i+1) = want andalso BenchQueens.strict (i+1) = want))
    (ListPair.zip (List.tabulate (10,fn i => i),solutions))
end
