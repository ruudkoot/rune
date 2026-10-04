structure BenchEffTests =
struct
  structure L = BenchLazy
  structure S = BenchStockState
  structure C = BenchChurchState
  structure D = BenchClassChurchState
  structure F = BenchFreeState
  val calls = ref 0
  fun increment n = (calls := !calls+1;n+1)
  val (_,state) = S.times 20 (S.modify increment)(S.value 0)
  val _ = T.check("eff/S-counter-unforced-at-pair",fn () => !calls=0)
  val _ = T.check("eff/S-counter-force-and-share",fn () =>
    L.force state=20 andalso !calls=20 andalso L.force state=20 andalso !calls=20)
  val _ = T.check("eff/S-unused-throwing-counter",fn () =>
    #1(S.times 5 (S.modify(fn _ => raise Fail "unused counter"))(S.value 0))=())
  val _ = T.check("eff/CS-strict-new-state",fn () =>
    ((C.runState(C.modify(fn _ => raise Fail "demanded counter"))0;false)handle Fail _ => true))
  val _ = T.check("eff/FS-strict-put-field",fn () =>
    ((F.runState(F.modify(fn _ => raise Fail "demanded counter"))0;false)handle Fail _ => true))
  val _ = T.check("eff/strict-variant-results",fn () =>
    List.all(fn n => C.run n=((),n) andalso D.run n=((),n) andalso F.run n=((),n)) [0,1,10,100])
  val _ = T.check("eff/CS-action-count",fn () =>
    let val observed = ref 0
        val result = C.runState(C.times 30 (C.modify(fn s => (observed := !observed+1;s+1))))0
    in result=((),30) andalso !observed=30 end)
  val _ = T.check("eff/FS-action-count",fn () =>
    let val observed = ref 0
        val result = F.runState(F.times 30 (F.modify(fn s => (observed := !observed+1;s+1))))0
    in result=((),30) andalso !observed=30 end)
  val _ = T.check("eff/FS-continuation-unused-before-put",fn () =>
    let val action = L.delay(fn () => F.Put(5,L.delay(fn () => raise Fail "unneeded continuation")))
    in case L.force(F.bind action (fn _ => F.pure())) of F.Put(value,_) => value=5 | _ => false end)
  val _ = T.check("eff/VS-result",fn () => BenchVanState.run 100=((),100))
  val _ = T.check("eff/VSD-result",fn () => L.force(#2(BenchClassVanState.run 100))=100)
  val _ = T.check("eff/VSM-result",fn () => L.force(#2(BenchVanMtlState.run 100))=100)
  val _ = T.check("eff/VSD-strict-modify",fn () =>
    ((S.times 2 (BenchClassVanState.modify BenchClassVanState.stateDictionary
        (fn _ => raise Fail "demanded counter"))(S.value 0);false)handle Fail _ => true))
  val _ = T.check("eff/VSM-strict-modify",fn () =>
    ((BenchVanMtlState.times 2 (BenchVanMtlState.modify(fn _ => raise Fail "demanded counter"))
       S.get S.put(S.value 0);false)handle Fail _ => true))
end
