from pathlib import Path
import shutil
p=Path(__file__).resolve().parent;data=p/'data';data.mkdir(exist_ok=True)
files=['small.observe','suite-normal.observe','suite-normal.input','suite-normal.expected','scalar-powers.data']
for name in files:shutil.copyfile(p/name,data/name)
body=r'''
  structure I=IntInf
  structure L=BenchLazy
  structure S=BenchStream
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  fun lines text=String.tokens(fn c=>c= #"\n")text
  fun integer text=valOf(I.fromString text)
  fun checkState file=
    let val rows=lines(read file)
        val wanted=List.map integer(tl(String.tokens Char.isSpace(hd rows)))
        val _=T.check("primetest/"^mode^"/raw-prefix/"^file,fn()=>
          ListPair.allEq(op =)(S.take 16(K.initial()),wanted))
        fun next(line,source)=case String.tokens Char.isSpace line of
            [index,number,passed,a,b,c,d]=>
              let val(result,after)=K.multiTest 100 source(K.readInteger number)
                  val _=T.check("primetest/"^mode^"/state/"^file^"/"^index,fn()=>
                    result=(passed="1")andalso
                    ListPair.allEq(op =)(S.take 4 after,List.map integer[a,b,c,d]))
              in after end
           |_=>raise Fail "invalid prime state fixture"
    in List.foldl next(K.initial())(tl rows);()end
  val _=checkState "small.observe"
  val _=checkState "suite-normal.observe"
  fun power line=case String.tokens Char.isSpace line of [a,b,m,wanted]=>
    T.check("primetest/"^mode^"/power/"^b^"/"^m,fn()=>K.powerMod(integer a)(integer b)(integer m)=integer wanted)
    |_=>raise Fail "invalid modular power fixture"
  val _=List.app power(lines(read "scalar-powers.data"))
  val _=T.check("primetest/"^mode^"/complete-normal-output",fn()=>
    Driver.run["suite-normal.input"]^"\n"=read "suite-normal.expected")
  val _=T.check("primetest/"^mode^"/fresh-process-state",fn()=>
    K.process 100["3","5","9"]=K.process 100["3","5","9"])
  val _=T.check("primetest/"^mode^"/driver-empty-lines",fn()=>Driver.lines ""=[])
  val _=T.check("primetest/"^mode^"/driver-final-lf",fn()=>Driver.lines "2\n3\n"=["2","3"])
  val _=T.check("primetest/"^mode^"/driver-preserves-blank-lines",fn()=>Driver.lines "2\n\n"=["2",""])
  val _=T.check("primetest/"^mode^"/driver-arity-rejected",fn()=>((Driver.run[];false)handle Fail _=>true))
  val _=T.check("primetest/"^mode^"/empty-process",fn()=>K.process 100[]="")
  val _=T.check("primetest/"^mode^"/read-negative",fn()=>K.readInteger " -1 "= ~1)
  val _=T.check("primetest/"^mode^"/read-trailing-junk-rejected",fn()=>
    ((K.readInteger "123tail";false)handle Fail _=>true))
  val _=T.check("primetest/"^mode^"/zero-rounds-retain-source",fn()=>
    let val(result,after)=K.multiTest 0(K.initial())9
    in result andalso ListPair.allEq(op =)(S.take 4 after,S.take 4(K.initial()))end)
  val _=T.check("primetest/"^mode^"/find-kq",fn()=>K.findKQ 17=(4,1)andalso K.findKQ 341=(2,85)andalso K.findKQ 65537=(16,1))
  val _=T.check("primetest/"^mode^"/base-65536-roundtrip",fn()=>
    List.all(fn n=>K.makeNumber 65536(K.chop 65536 n)=n)
      (List.map integer["0","1","65535","65536","65537","4294967295","4294967296","123456789012345678901234567890"]))
  fun ofList xs=D.delay(fn()=>case xs of []=>K.Nil
    |x::rest=>K.Cons(D.delay(fn()=>x),ofList rest))
  val _=T.check("primetest/"^mode^"/uniform-bound-prefix",fn()=>
    K.makeNumber 65536(K.uniform(ofList[1,1])(ofList[3,5]))=65536)
  val _=T.check("primetest/"^mode^"/uniform-smaller-prefix",fn()=>
    K.makeNumber 65536(K.uniform(ofList[1,1])(ofList[2,5]))=5)
  val _=T.check("primetest/"^mode^"/source-zero-low-digit-partiality",fn()=>
    ((K.makeNumber 65536(K.uniform(ofList[1,0])(ofList[1,4]));false)handle Div=>true))
  val _=T.check("primetest/"^mode^"/take-zero-unused-stream",fn()=>
    case D.force(K.take 0(L.delay(fn()=>raise Fail "unused stream")))of K.Nil=>true|_=>false)
  val _=T.check("primetest/"^mode^"/split-head-shared",fn()=>
    let val calls=ref 0
        val source=S.cons(L.delay(fn()=>(calls:= !calls+1;(7:I.int))),S.empty())
        val(prefix,_)=K.splitAt 1 source
    in case D.force prefix of K.Cons(x,_)=>D.force x=7 andalso D.force x=7 andalso !calls=1|_=>false end)
'''
text=''
for mode,policy in [('Need','BenchNeed'),('Strict','BenchStrict')]:
 text+='structure '+mode+'Prime=BenchPrimeTestFn('+policy+')\nstructure '+mode+'Driver=BenchPrimeTestDriverFn('+mode+'Prime)\nstructure '+mode+'PrimeTests=struct\nstructure K='+mode+'Prime\nstructure Driver='+mode+'Driver\nstructure D='+policy+'\nval mode="'+mode+'"\n'+body+'end\n'
text+=r'''
structure PrimeDemand =
struct
  structure K=NeedPrime
  structure D=BenchNeed
  structure L=BenchLazy
  structure S=BenchStream
  val _=T.check("primetest/lazy-initial-one-skips-tail",fn()=>
    K.testPowers 7(D.delay(fn()=>K.Cons(D.delay(fn()=>1),D.delay(fn()=>raise Fail "unused tail")))))
  val _=T.check("primetest/lazy-secondary-minus-one-skips-tail",fn()=>
    K.testPowers 7(D.delay(fn()=>K.Cons(D.delay(fn()=>2),
      D.delay(fn()=>K.Cons(D.delay(fn()=>6),D.delay(fn()=>raise Fail "unused tail")))))))
  val _=T.check("primetest/lazy-secondary-one-stops-false",fn()=>
    not(K.testPowers 7(D.delay(fn()=>K.Cons(D.delay(fn()=>2),
      D.delay(fn()=>K.Cons(D.delay(fn()=>1),D.delay(fn()=>raise Fail "unused tail"))))))))
  val _=T.check("primetest/lazy-split-tail-skips-heads",fn()=>
    let val source=S.cons(L.delay(fn()=>raise Fail "unused head"),
          S.cons(L.delay(fn()=>raise Fail "unused second"),S.singleton(3:IntInf.int)))
        val(_,after)=K.splitAt 2 source
    in S.head after=3 end)
  val _=T.check("primetest/strict-selected-powers-are-eager",fn()=>
    ((StrictPrime.take 2(S.cons(L.delay(fn()=>(1:IntInf.int)),
      S.cons(L.delay(fn()=>raise Fail "eager second power"),S.empty())));false)handle Fail _=>true))
end
'''
(p/'tests.sml').write_text(text);root=Path.cwd();sources=['tests/basis/harness.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/stream.sml','examples/benchmarks/shared/scs-random.sml',str(p/'kernel.sml'),str(p/'driver.sml'),str(p/'tests.sml'),'tests/basis/finish.sml'];(p/'test-sources.txt').write_text(''.join(str(root/f)+'\n'for f in sources));(p/'test-data.txt').write_text(''.join(name+'\n'for name in files))
