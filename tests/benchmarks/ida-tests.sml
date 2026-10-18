functor IdaTestsFn(D:BENCH_SUSPEND)=struct
 structure B=BenchIdaFn(D)
 structure Driver=BenchIdaDriverFn(B)
 open B
 fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
 val base=""
 fun check name f=T.check("ida/"^name,f)
 fun showCase(seed,w,h,n)=
   let val configuration=initial seed w h n val solution=solve configuration 7(n+1)
       val space=solutionSpace solution
       val _=if validSolution(configuration,solution)then()else raise Fail"invalid path"
       val description=showConfiguration configuration
       val conf=String.substring(description,0,String.size description-1)
       val history=String.concat(rev(S.foldl(fn(p,ps)=>showPos p::ps)[](path space)))
   in "("^Int.toString seed^","^Int.toString w^","^Int.toString h^","^Int.toString n^") "^conf^" | "^
     Int.toString(bound space)^" "^Int.toString(partitions solution)^" "^Int.toString(depth space)^" "^history end
 val _=check "original-case/0"(fn()=>showCase(0,2,3,0)="(0,2,3,0) (1,1)((1,2)-(1,2))((2,1)-(2,1))((1,3)-(1,3))((2,2)-(2,2))((2,3)-(2,3)) | 0 0 0 (1,1)")
 val _=check "original-case/1"(fn()=>showCase(0,2,3,1)="(0,2,3,1) (2,1)((1,1)-(2,1))((2,2)-(2,2))((1,3)-(1,3))((2,3)-(2,3))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/2"(fn()=>showCase(0,2,3,5)="(0,2,3,5) (2,3)((2,2)-(2,3))((1,3)-(1,3))((1,1)-(1,2))((2,1)-(2,1))((1,2)-(2,2)) | 3 2 0 (1,1)(1,2)(2,2)(2,3)")
 val _=check "original-case/3"(fn()=>showCase(0,2,3,20)="(0,2,3,20) (2,2)((2,3)-(2,3))((2,1)-(2,2))((1,2)-(1,2))((1,1)-(2,1))((1,3)-(1,3)) | 2 0 0 (1,1)(2,1)(2,2)")
 val _=check "original-case/4"(fn()=>showCase(0,2,4,0)="(0,2,4,0) (1,1)((1,2)-(1,2))((2,1)-(2,1))((1,3)-(1,3))((1,4)-(1,4))((2,2)-(2,2))((2,3)-(2,3))((2,4)-(2,4)) | 0 0 0 (1,1)")
 val _=check "original-case/5"(fn()=>showCase(0,2,4,1)="(0,2,4,1) (2,1)((1,1)-(2,1))((2,2)-(2,2))((1,3)-(1,3))((1,4)-(1,4))((2,3)-(2,3))((2,4)-(2,4))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/6"(fn()=>showCase(0,2,4,5)="(0,2,4,5) (2,3)((2,2)-(2,3))((2,4)-(2,4))((1,3)-(1,3))((1,4)-(1,4))((1,1)-(1,2))((2,1)-(2,1))((1,2)-(2,2)) | 3 2 0 (1,1)(1,2)(2,2)(2,3)")
 val _=check "original-case/7"(fn()=>showCase(0,2,4,20)="(0,2,4,20) (1,3)((1,4)-(2,4))((1,2)-(1,3))((2,3)-(1,4))((1,1)-(1,2))((2,1)-(2,1))((2,2)-(2,2))((2,4)-(2,3)) | 6 4 0 (1,1)(1,2)(1,3)(1,4)(2,4)(2,3)(1,3)")
 val _=check "original-case/8"(fn()=>showCase(0,3,3,0)="(0,3,3,0) (1,1)((1,2)-(1,2))((2,1)-(2,1))((1,3)-(1,3))((2,2)-(2,2))((2,3)-(2,3))((3,1)-(3,1))((3,2)-(3,2))((3,3)-(3,3)) | 0 0 0 (1,1)")
 val _=check "original-case/9"(fn()=>showCase(0,3,3,1)="(0,3,3,1) (2,1)((1,1)-(2,1))((2,2)-(2,2))((3,1)-(3,1))((1,3)-(1,3))((2,3)-(2,3))((3,2)-(3,2))((3,3)-(3,3))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/10"(fn()=>showCase(0,3,3,5)="(0,3,3,5) (2,1)((1,1)-(2,2))((3,1)-(3,1))((2,2)-(1,2))((3,3)-(3,3))((2,3)-(2,3))((3,2)-(3,2))((1,3)-(1,3))((1,2)-(2,1)) | 5 3 0 (1,1)(2,1)(2,2)(1,2)(1,1)(2,1)")
 val _=check "original-case/11"(fn()=>showCase(0,3,3,20)="(0,3,3,20) (2,2)((3,2)-(3,2))((2,3)-(2,3))((1,2)-(1,2))((2,1)-(2,2))((1,3)-(1,3))((1,1)-(2,1))((3,3)-(3,3))((3,1)-(3,1)) | 2 1 0 (1,1)(2,1)(2,2)")
 val _=check "original-case/12"(fn()=>showCase(6,2,3,0)="(6,2,3,0) (1,1)((1,2)-(1,2))((2,1)-(2,1))((1,3)-(1,3))((2,2)-(2,2))((2,3)-(2,3)) | 0 0 0 (1,1)")
 val _=check "original-case/13"(fn()=>showCase(6,2,3,1)="(6,2,3,1) (2,1)((1,1)-(2,1))((2,2)-(2,2))((1,3)-(1,3))((2,3)-(2,3))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/14"(fn()=>showCase(6,2,3,5)="(6,2,3,5) (2,1)((1,1)-(2,1))((2,2)-(2,2))((2,3)-(2,3))((1,3)-(1,3))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/15"(fn()=>showCase(6,2,3,20)="(6,2,3,20) (2,2)((1,2)-(1,3))((2,1)-(2,1))((2,3)-(2,2))((1,1)-(1,2))((1,3)-(2,3)) | 4 1 0 (1,1)(1,2)(1,3)(2,3)(2,2)")
 val _=check "original-case/16"(fn()=>showCase(6,2,4,0)="(6,2,4,0) (1,1)((1,2)-(1,2))((2,1)-(2,1))((1,3)-(1,3))((1,4)-(1,4))((2,2)-(2,2))((2,3)-(2,3))((2,4)-(2,4)) | 0 0 0 (1,1)")
 val _=check "original-case/17"(fn()=>showCase(6,2,4,1)="(6,2,4,1) (2,1)((1,1)-(2,1))((2,2)-(2,2))((1,3)-(1,3))((1,4)-(1,4))((2,3)-(2,3))((2,4)-(2,4))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/18"(fn()=>showCase(6,2,4,5)="(6,2,4,5) (2,1)((1,1)-(2,1))((2,2)-(2,2))((1,4)-(1,4))((2,3)-(2,3))((2,4)-(2,4))((1,3)-(1,3))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/19"(fn()=>showCase(6,2,4,20)="(6,2,4,20) (2,2)((2,3)-(2,3))((2,1)-(2,2))((1,2)-(1,2))((1,1)-(2,1))((1,4)-(1,4))((2,4)-(2,4))((1,3)-(1,3)) | 2 0 0 (1,1)(2,1)(2,2)")
 val _=check "original-case/20"(fn()=>showCase(6,3,3,0)="(6,3,3,0) (1,1)((1,2)-(1,2))((2,1)-(2,1))((1,3)-(1,3))((2,2)-(2,2))((2,3)-(2,3))((3,1)-(3,1))((3,2)-(3,2))((3,3)-(3,3)) | 0 0 0 (1,1)")
 val _=check "original-case/21"(fn()=>showCase(6,3,3,1)="(6,3,3,1) (2,1)((1,1)-(2,1))((2,2)-(2,2))((3,1)-(3,1))((1,3)-(1,3))((2,3)-(2,3))((3,2)-(3,2))((3,3)-(3,3))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/22"(fn()=>showCase(6,3,3,5)="(6,3,3,5) (2,1)((3,1)-(3,1))((1,1)-(2,1))((2,2)-(2,2))((1,3)-(1,3))((2,3)-(2,3))((1,2)-(1,2))((3,3)-(3,3))((3,2)-(3,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/23"(fn()=>showCase(6,3,3,20)="(6,3,3,20) (2,2)((1,2)-(1,3))((2,3)-(2,2))((3,2)-(3,2))((2,1)-(2,1))((3,3)-(3,3))((3,1)-(3,1))((1,3)-(2,3))((1,1)-(1,2)) | 4 2 0 (1,1)(1,2)(1,3)(2,3)(2,2)")
 val _=check "original-case/24"(fn()=>showCase(42,2,3,0)="(42,2,3,0) (1,1)((1,2)-(1,2))((2,1)-(2,1))((1,3)-(1,3))((2,2)-(2,2))((2,3)-(2,3)) | 0 0 0 (1,1)")
 val _=check "original-case/25"(fn()=>showCase(42,2,3,1)="(42,2,3,1) (2,1)((1,1)-(2,1))((2,2)-(2,2))((1,3)-(1,3))((2,3)-(2,3))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/26"(fn()=>showCase(42,2,3,5)="(42,2,3,5) (2,1)((2,2)-(2,1))((1,1)-(1,2))((1,3)-(1,3))((1,2)-(2,2))((2,3)-(2,3)) | 3 2 0 (1,1)(1,2)(2,2)(2,1)")
 val _=check "original-case/27"(fn()=>showCase(42,2,3,20)="(42,2,3,20) (1,3)((2,3)-(1,3))((1,2)-(2,1))((1,1)-(2,2))((2,1)-(1,2))((2,2)-(2,3)) | 8 5 0 (1,1)(1,2)(2,2)(2,1)(1,1)(1,2)(2,2)(2,3)(1,3)")
 val _=check "original-case/28"(fn()=>showCase(42,2,4,0)="(42,2,4,0) (1,1)((1,2)-(1,2))((2,1)-(2,1))((1,3)-(1,3))((1,4)-(1,4))((2,2)-(2,2))((2,3)-(2,3))((2,4)-(2,4)) | 0 0 0 (1,1)")
 val _=check "original-case/29"(fn()=>showCase(42,2,4,1)="(42,2,4,1) (2,1)((1,1)-(2,1))((2,2)-(2,2))((1,3)-(1,3))((1,4)-(1,4))((2,3)-(2,3))((2,4)-(2,4))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/30"(fn()=>showCase(42,2,4,5)="(42,2,4,5) (2,1)((2,2)-(2,1))((1,1)-(1,2))((1,4)-(1,4))((2,4)-(2,4))((1,3)-(1,3))((1,2)-(2,2))((2,3)-(2,3)) | 3 2 0 (1,1)(1,2)(2,2)(2,1)")
 val _=check "original-case/31"(fn()=>showCase(42,2,4,20)="(42,2,4,20) (1,3)((2,3)-(1,3))((1,4)-(1,4))((1,2)-(2,1))((1,1)-(2,2))((2,1)-(1,2))((2,2)-(2,3))((2,4)-(2,4)) | 8 6 0 (1,1)(1,2)(2,2)(2,1)(1,1)(1,2)(2,2)(2,3)(1,3)")
 val _=check "original-case/32"(fn()=>showCase(42,3,3,0)="(42,3,3,0) (1,1)((1,2)-(1,2))((2,1)-(2,1))((1,3)-(1,3))((2,2)-(2,2))((2,3)-(2,3))((3,1)-(3,1))((3,2)-(3,2))((3,3)-(3,3)) | 0 0 0 (1,1)")
 val _=check "original-case/33"(fn()=>showCase(42,3,3,1)="(42,3,3,1) (2,1)((1,1)-(2,1))((2,2)-(2,2))((3,1)-(3,1))((1,3)-(1,3))((2,3)-(2,3))((3,2)-(3,2))((3,3)-(3,3))((1,2)-(1,2)) | 1 0 0 (1,1)(2,1)")
 val _=check "original-case/34"(fn()=>showCase(42,3,3,5)="(42,3,3,5) (2,1)((2,2)-(2,1))((3,1)-(3,1))((1,1)-(1,2))((3,3)-(3,3))((1,3)-(1,3))((1,2)-(2,2))((2,3)-(2,3))((3,2)-(3,2)) | 3 2 0 (1,1)(1,2)(2,2)(2,1)")
 val _=check "original-case/35"(fn()=>showCase(42,3,3,20)="(42,3,3,20) (1,1)((1,2)-(2,1))((2,1)-(3,1))((3,3)-(3,3))((3,1)-(3,2))((2,3)-(2,3))((3,2)-(2,2))((2,2)-(1,2))((1,3)-(1,3)) | 6 4 0 (1,1)(2,1)(3,1)(3,2)(2,2)(1,2)(1,1)")
 val _=check "original-case/36"(fn()=>showCase(6,3,4,100)="(6,3,4,100) (3,3)((2,3)-(1,4))((3,4)-(3,4))((3,2)-(3,2))((1,1)-(2,2))((3,1)-(3,1))((2,1)-(3,3))((1,2)-(2,1))((1,4)-(2,3))((1,3)-(1,2))((2,2)-(1,3))((2,4)-(2,4)) | 22 994 0 (1,1)(2,1)(2,2)(1,2)(1,3)(2,3)(3,3)(3,4)(2,4)(1,4)(1,3)(1,2)(2,2)(2,3)(1,3)(1,2)(1,1)(2,1)(2,2)(2,3)(2,4)(3,4)(3,3)")
 val _=check "source-smoke-output"(fn()=>one 2=read(base^"smoke.one"))
 val _=check "source-normal-output"(fn()=>one 3=read(base^"normal.one"))
 val _=check "source-reversed-random-prefix"(fn()=>reversedPrefix 4[](random 6)=[19508, 13637, 102, 27979])
 val _=check "singleton-skips-board-path"(fn()=>
   let val state=ready(Search(ready 0,ready 0,delay(fn()=>raise Fail"board"),delay(fn()=>raise Fail"path")))
   in singleton(forcedCheck state)end)
 val _=check "choose-prefers-first-solved-tie"(fn()=>
   let val solved=ready(Search(ready 3,ready 0,delay(fn()=>raise Fail"board"),S.empty()))
       val other=ready(Search(ready 3,delay(fn()=>raise Fail"depth"),delay(fn()=>raise Fail"board"),S.empty()))
   in singleton(choose solved other)end)
 val _=check "choose-unequal-skips-depth"(fn()=>
   let fun node b=ready(Search(ready b,delay(fn()=>raise Fail"depth"),delay(fn()=>raise Fail"board"),S.empty()))
   in bound(choose(node 2)(node 3))=2 end)
 val _=check "branch-cutoff-skips-pending-space"(fn()=>
   let val optimum=ready(Search(ready 5,ready 0,delay(fn()=>raise Fail"board"),S.empty()))
       val result=branch 7 ~5(S.cons(delay(fn()=>raise Fail"space"),S.empty()))(ready(Solution(optimum,ready 9)))
   in partitions result=9 end)
 val _=check "collect-matches-both-solution-roots"(fn()=>
   let val first=ready(Solution(ready(Search(ready 0,ready 0,ready(F.empty(),F.empty()),S.empty())),ready 0))
   in((L.force(collect first(delay(fn()=>raise Fail"solution")));false)handle Fail why=>why="solution")end)
 val _=check "partition-shares-source-predicate"(fn()=>
   let val calls=ref 0 fun predicate n=(calls:= !calls+1;n mod 2=0)
       val(yes,no)=split predicate(S.fromList[1,2,3,4])
       val values=S.take 4 yes val others=S.take 4 no
   in values=[2,4]andalso others=[1,3]andalso !calls=4 end)
 val _=check "finite-partition-shares-source-predicate"(fn()=>
   let val calls=ref 0 fun predicate n=(calls:= !calls+1;n mod 2=0)
       val shared=splitFinite predicate(F.fromList[1,2,3,4])
       val(yes,no)=L.force shared val values=F.toList yes val others=F.toList no
   in values=[2,4]andalso others=[1,3]andalso !calls=4 end)
 val _=check "negative-seed-absolute"(fn()=>
   showConfiguration(initial ~6 2 4 100)=showConfiguration(initial 6 2 4 100))
 val _=check "random-zero-prefix-unforced"(fn()=>
   null(reversedPrefix 0[](delay(fn()=>raise Fail"numbers"))))
 val _=check "zero-repetitions"(fn()=>calculate 0 3"unused"="0 0")
 val _=check "consumer-validates-output"(fn()=>calculate 2 2(read(base^"smoke.one"))=
   "2 "^Int.toString(2*String.size(read(base^"smoke.one"))))
 val _=check "incorrect-reference-rejected"(fn()=>((calculate 1 2"wrong";false)handle Fail why=>String.isPrefix"incorrect result:"why))
 val _=check "invalid-path-rejected"(fn()=>
   let val configuration=goal 2 4
       val bad=ready(Solution(ready(Search(ready 0,ready 0,ready(F.empty(),F.empty()),S.singleton(2,2))),ready 0))
   in not(validSolution(configuration,bad))end)
end
structure NeedIdaTests=IdaTestsFn(BenchNeed)
structure StrictIdaTests=IdaTestsFn(BenchStrict)

val _=T.check("ida/lazy-finite-field-demand",fn()=>
 let val mapped=NeedIdaTests.F.map(fn _=>raise Fail "tile")(NeedIdaTests.F.fromList[1])
 in (case BenchLazy.force mapped of NeedIdaTests.F.Cons _=>true|_=>false)end)
val _=T.check("ida/strict-finite-field-demand",fn()=>
 ((StrictIdaTests.F.map(fn _=>raise Fail "tile")(StrictIdaTests.F.fromList[1]);false)
   handle Fail why=>why="tile"))
