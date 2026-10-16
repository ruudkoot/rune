structure NeedGenerator=BenchHartelGenFftFn(BenchNeed)
structure StrictGenerator=BenchHartelGenFftFn(BenchStrict)
structure NeedDriver=BenchHartelGenFftDriverFn(NeedGenerator)
structure StrictDriver=BenchHartelGenFftDriverFn(StrictGenerator)
structure GenFftTests =
struct
  structure N=NeedGenerator
  structure R=StrictGenerator
  fun read name=let val f=TextIO.openIn name val s=TextIO.inputAll f val _=TextIO.closeIn f in s end
  fun code s=CharVector.foldl(fn(c,sum)=>sum+Char.ord c)0 s+String.size s
  fun chars xs=case BenchNeed.force xs of N.Nil=>[]|N.Cons(x,rest)=>BenchNeed.force x::chars rest
  fun strictChars xs=case BenchStrict.force xs of R.Nil=>[]|R.Cons(x,rest)=>BenchStrict.force x::strictChars rest
  val _=T.check("genfft/lazy-complete-0",fn()=>N.check 0(read "0.program")=(0,0))
  val _=T.check("genfft/strict-complete-0",fn()=>R.check 0(read "0.program")=(0,0))
  val _=T.check("genfft/lazy-complete-1",fn()=>N.check 1(read "1.program")=(45493,608))
  val _=T.check("genfft/strict-complete-1",fn()=>R.check 1(read "1.program")=(45493,608))
  val _=T.check("genfft/lazy-complete-2",fn()=>N.check 2(read "2.program")=(154260,2044))
  val _=T.check("genfft/strict-complete-2",fn()=>R.check 2(read "2.program")=(154260,2044))
  val _=T.check("genfft/lazy-complete-3",fn()=>N.check 3(read "3.program")=(417707,5532))
  val _=T.check("genfft/strict-complete-3",fn()=>R.check 3(read "3.program")=(417707,5532))
  val _=T.check("genfft/lazy-complete-4",fn()=>N.check 4(read "4.program")=(1048289,13937))
  val _=T.check("genfft/strict-complete-4",fn()=>R.check 4(read "4.program")=(1048289,13937))
  val _=T.check("genfft/lazy-complete-5",fn()=>N.check 5(read "5.program")=(2522857,33650))
  val _=T.check("genfft/strict-complete-5",fn()=>R.check 5(read "5.program")=(2522857,33650))
  val _=T.check("genfft/lazy-complete-6",fn()=>N.check 6(read "6.program")=(5925859,79360))
  val _=T.check("genfft/strict-complete-6",fn()=>R.check 6(read "6.program")=(5925859,79360))
  val _=T.check("genfft/lazy-complete-7",fn()=>N.check 7(read "7.program")=(13735234,185243))
  val _=T.check("genfft/strict-complete-7",fn()=>R.check 7(read "7.program")=(13735234,185243))
  val _=T.check("genfft/lazy-complete-8",fn()=>N.check 8(read "8.program")=(31387091,426210))
  val _=T.check("genfft/strict-complete-8",fn()=>R.check 8(read "8.program")=(31387091,426210))
  val _=T.check("genfft/lazy-repeat-3",fn()=>NeedDriver.run["3","2","3.program"]="2:417707/5532:24")
  val _=T.check("genfft/strict-repeat-3",fn()=>StrictDriver.run["3","2","3.program"]="2:417707/5532:24")
  val _=T.check("genfft/lazy-repeat-6",fn()=>NeedDriver.run["6","2","6.program"]="2:5925859/79360:28")
  val _=T.check("genfft/strict-repeat-6",fn()=>StrictDriver.run["6","2","6.program"]="2:5925859/79360:28")
  val _=T.check("genfft/lazy-repeat-8",fn()=>NeedDriver.run["8","2","8.program"]="2:31387091/426210:32")
  val _=T.check("genfft/strict-repeat-8",fn()=>StrictDriver.run["8","2","8.program"]="2:31387091/426210:32")
  val _=T.check("genfft/lazy-reject-wrong",fn()=>((ignore(N.check 3(read "wrong.program"));false)handle Fail message=>String.isPrefix "incorrect result:" message))
  val _=T.check("genfft/strict-reject-wrong",fn()=>((ignore(R.check 3(read "wrong.program"));false)handle Fail message=>String.isPrefix "incorrect result:" message))
  val _=T.check("genfft/lazy-reject-truncated",fn()=>((ignore(N.check 3(read "truncated.program"));false)handle Fail message=>String.isPrefix "incorrect result:" message))
  val _=T.check("genfft/strict-reject-truncated",fn()=>((ignore(R.check 3(read "truncated.program"));false)handle Fail message=>String.isPrefix "incorrect result:" message))
  val _=T.check("genfft/lazy-reject-extra",fn()=>((ignore(N.check 3(read "extra.program"));false)handle Fail message=>String.isPrefix "incorrect result:" message))
  val _=T.check("genfft/strict-reject-extra",fn()=>((ignore(R.check 3(read "extra.program"));false)handle Fail message=>String.isPrefix "incorrect result:" message))
  val _=T.check("genfft/lazy-reject-collision",fn()=>((ignore(N.check 3(read "collision.program"));false)handle Fail message=>String.isPrefix "incorrect result:" message))
  val _=T.check("genfft/strict-reject-collision",fn()=>((ignore(R.check 3(read "collision.program"));false)handle Fail message=>String.isPrefix "incorrect result:" message))
  val _=T.check("genfft/collision-has-same-source-checksum",fn()=>
    let val a=read "3.program" val b=read "collision.program"
    in a<>b andalso String.size a=String.size b andalso code a=code b end)
  val _=T.check("genfft/take-zero-does-not-demand-source",fn()=>
    case BenchNeed.force(N.take 0(BenchNeed.delay(fn()=>raise Fail "unused source")))of N.Nil=>true|_=>false)
  val _=T.check("genfft/append-shares-character-cell",fn()=>
    let val count=ref 0 val cell=BenchNeed.delay(fn()=>(count:= !count+1;#"x"))
        val source=BenchNeed.delay(fn()=>N.Cons(cell,N.empty()))
    in String.implode(chars(N.append source source))="xx"andalso !count=1 end)
  val _=T.check("genfft/singleton-glue-does-not-demand-separator",fn()=>
    String.implode(chars(N.glue(BenchNeed.delay(fn()=>raise Fail "unused separator"))(N.texts[N.text "ab"])))="ab")
  val _=T.check("genfft/lazy-empty-glue-is-partial",fn()=>((ignore(BenchNeed.force(N.glue(N.text "-")(N.empty())));false)handle Empty=>true))
  val _=T.check("genfft/strict-empty-glue-is-partial",fn()=>((ignore(R.glue(R.text "-")(R.empty()));false)handle Empty=>true))
  val _=T.check("genfft/strict-singleton-glue",fn()=>String.implode(strictChars(R.glue(R.text "-")(R.texts[R.text "ab"])))="ab")
end
