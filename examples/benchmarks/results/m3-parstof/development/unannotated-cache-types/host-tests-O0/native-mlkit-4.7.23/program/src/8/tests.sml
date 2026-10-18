
functor ParstofTestsFn(structure D:BENCH_SUSPEND val strict:bool val label:string)=struct
 structure K=BenchParstofFn(D)
 structure X=K.X
 structure L=BenchLazy
 structure Check=BenchParstofCheckFn(K)
 exception Demanded
 fun demand Demanded=true|demand _=false
 fun test name f=T.check("parstof/"^label^"/"^name,f)
 fun raises name f=T.raises("parstof/"^label^"/"^name,demand,f)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun original name=(
   test("tokens/"^name)(fn()=>K.dumpTokens(X.tokenize(read(name^".input")))^"\n"=read(name^"-tokens.reference"));
   test("parse/"^name)(fn()=>K.parseJSON(read(name^".input"))^"\n"=read(name^"-parse.reference")))
 val _=List.app original["default","identity","application","types","conditional","let-case","lexemes","bad","empty","unterminated-comment"]
 val token=L.delay(fn()=>X.Tok((12,X.Empty,1),L.delay(fn()=>X.Done)))
 val touches=ref 0
 val parser=K.convert(fn value=>(touches:= !touches+1;D.delay(fn()=>7)))(K.literal(fn _=>D.delay(fn()=>0))12)
 val _=test"attribute-callback-demand"(fn()=>case parser token of K.Success(value,_)=>
    !touches=(if strict then 1 else 0)andalso D.force value=7 andalso D.force value=7 andalso !touches=1|_=>false)
 val _=test"wrong-token-skips-callback"(fn()=>case K.literal(fn _=>raise Demanded)11 token of K.ParseFail K.Unknown=>true|_=>false)
 val _=test"alternative-left-success-skips-right"(fn()=>
   case K.alt[K.literal(fn _=>D.delay(fn()=>7))12,fn _=>raise Demanded]token of
     K.Success(n,_)=>D.force n=7|_=>false)
 val _=test"failed-first-skips-second"(fn()=>
   case K.sequence K.select1(K.literal(fn _=>D.delay(fn()=>7))11)(fn _=>raise Demanded)token of
     K.ParseFail K.Unknown=>true|_=>false)
 val _=test"conversion-skips-failure"(fn()=>
   case K.convert(fn _=>raise Demanded)(K.literal(fn _=>D.delay(fn()=>7))11)token of
    K.ParseFail K.Unknown=>true|_=>false)
 fun known message line _=K.ParseFail(K.Known(L.delay(fn()=>message),line))
 val _=test"best-error-prefers-later-line"(fn()=>case K.alt[known"first"1,known"later"2]token of
    K.ParseFail(K.Known(text,2))=>L.force text="later"|_=>false)
 val _=test"best-error-ties-preserve-left"(fn()=>case K.alt[known"first"2,known"second"2]token of
    K.ParseFail(K.Known(text,2))=>L.force text="first"|_=>false)
 val _=test"repetition-recovers-known-error"(fn()=>
   case K.repeat K.select1(D.delay(fn()=>42))(known"error"2)token of K.Success(value,_)=>D.force value=42|_=>false)
 val _=test"optional-recovers-known-error"(fn()=>
   case K.optional(D.delay(fn()=>42))(known"error"2)token of K.Success(value,_)=>D.force value=42|_=>false)
 val _=test"known-error-does-not-reformat"(fn()=>
   case K.fail(fn _=>raise Demanded)(known"retained"9)token of
     K.ParseFail(K.Known(text,9))=>L.force text="retained"|_=>false)
 val messageHits=ref 0
 val error=K.fail(fn _=>(messageHits:= !messageHits+1;"deferred error"))(K.literal(fn _=>D.delay(fn()=>0))11)token
 val _=test"error-text-deferred-and-shared"(fn()=>
   case error of K.ParseFail(K.Known(text,1))=>
     !messageHits=0 andalso L.force text="deferred error"andalso
     L.force text="deferred error"andalso !messageHits=1|_=>false)
 val grammar=K.cache_c_par_proglist
 val _=test"grammar-closure-shared"(fn()=>
   case !grammar of NONE=>false|SOME _=>
    let val hits=ref 0 val original= !grammar
        val _=grammar:=SOME(fn tokens=>(hits:= !hits+1;case original of SOME parser=>parser tokens|NONE=>raise Demanded))
        val _=ignore(K.c_par_proglist(X.tokenize""))
        val _=ignore(K.c_par_proglist(X.tokenize""))
        val _=grammar:=original
    in !hits=2 end)
 val _=test"source-success-message-checksum"(fn()=>K.benchmark 1(K.input(read"default.input"))="2483/26\n")
 val _=test"source-normal-inner-count"(fn()=>K.benchmark 8(K.input(read"default.input"))="19864/208\n")
 val _=test"source-zero-programs-skips-input"(fn()=>K.benchmark 0(L.delay(fn()=>raise Demanded))="0/0\n")
 val _=test"driver-zero-repetitions"(fn()=>Check.run["0","1","default.input","count-1.crc"]="0:0:0")
 val _=test"driver-one-iteration"(fn()=>Check.run["1","1","default.input","count-1.crc"]="1:1:8")
 val _=T.raises("parstof/"^label^"/reject-bad-program",fn Fail _=>true|_=>false,
   fn()=>K.benchmark 1(K.input(read"bad.input")))
 val _=T.raises("parstof/"^label^"/reject-bad-checksum",fn Fail _=>true|_=>false,
   fn()=>Check.run["1","1","default.input","wrong.crc"])
 val callback:X.tokens L.delay->int D.t K.parsed=K.convert(fn _=>raise Demanded)(K.literal(fn _=>D.delay(fn()=>0))12)
 val _=if strict then raises"strict-forces-finite-attribute"(fn()=>callback token)
   else test"lazy-recognition-skips-poison-attribute"(fn()=>case callback token of K.Success _=>true|_=>false)
 val _=if strict then()else raises"lazy-poison-demanded-by-consumer"(fn()=>
   case callback token of K.Success(value,_)=>D.force value|_=>raise Fail"expected success")
end
structure NeedParstofTests=ParstofTestsFn(structure D=BenchNeed val strict=false val label="need")
structure StrictParstofTests=ParstofTestsFn(structure D=BenchStrict val strict=true val label="strict")
