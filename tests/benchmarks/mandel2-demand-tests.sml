structure MandelDemandPoint =
struct
  val calls : (int * int) list ref = ref []
  val mode = ref 0
  fun colour (p as (x, y)) =
    (calls := p :: !calls;
     case !mode of 0 => if x = 0 then 2 else 3
       | 1 => 2
       | _ => if y = 0 then 2 else 1)
  fun reset n = (mode := n; calls := [])
  fun trace () = List.rev (!calls)
end
structure DemandNeed = BenchMandelTwoFn (structure D = BenchNeed structure P = MandelDemandPoint)
structure DemandStrict = BenchMandelTwoFn (structure D = BenchStrict structure P = MandelDemandPoint)
structure MandelDemandTests =
struct
  structure P = MandelDemandPoint
  val _ = T.check ("mandel2/lazy-corner-short-circuit", fn () =>
    (P.reset 0; DemandNeed.perimeter ((0,0),(2,2)) = ~1 andalso P.trace () = [(0,0),(2,0)]))
  val _ = T.check ("mandel2/strict-corners-eager", fn () =>
    (P.reset 0; DemandStrict.perimeter ((0,0),(2,2)) = ~1 andalso P.trace () = [(0,0),(2,0),(2,2),(0,2)]))
  val _ = T.check ("mandel2/lazy-shared-colour-one", fn () =>
    (P.reset 1; DemandNeed.perimeter ((0,0),(1,1)) = 2 andalso P.trace () = [(0,0),(1,0),(1,1),(0,1)]))
  val _ = T.check ("mandel2/single-point-no-unused-corners", fn () =>
    (P.reset 1; DemandNeed.perimeter ((0,0),(0,0)) = 2 andalso P.trace () = [(0,0)]))
  val _ = T.check ("mandel2/zero-height-source-outward-scan", fn () =>
    (P.reset 2; DemandNeed.perimeter ((0,0),(1,0)) = ~1 andalso List.exists (fn p => p = (1,1)) (P.trace ())))
  val _ = T.check ("mandel2/right-whnf-before-left-and-memoized", fn () =>
    let val _ = P.reset 0 val tree = DemandNeed.build (0,0) (1,0)
        val unforced = P.trace () = []
    in case BenchNeed.force tree of DemandNeed.NS (left, right) =>
         let val initial = P.trace () = [(0,0),(1,0),(1,0)]
             val _ = BenchNeed.force right
             val shared = P.trace () = [(0,0),(1,0),(1,0)]
             val _ = BenchNeed.force left
         in unforced andalso initial andalso shared andalso P.trace () = [(0,0),(1,0),(1,0),(0,0)] end
       | _ => false end)
  val _ = T.check ("mandel2/strict-right-complete-before-left", fn () =>
    (P.reset 0; ignore (DemandStrict.build (0,0) (1,0)); P.trace () = [(0,0),(1,0),(1,0),(0,0),(1,0),(0,0)]))
end
