structure BenchStreamTests =
struct
  val spineCalls=ref 0
  val headCalls=ref 0
  val tailCalls=ref 0
  val source=BenchLazy.delay(fn()=>
    (spineCalls := !spineCalls+1;
     BenchStream.Cons(BenchLazy.delay(fn()=>(headCalls := !headCalls+1;13)),
       BenchLazy.delay(fn()=>(tailCalls := !tailCalls+1;raise Fail "unwanted tail")))))
  val mapped=BenchStream.map(fn x=>x+4)source
  val _=T.check("stream.construct/demand",fn()=> !spineCalls=0 andalso !headCalls=0)
  val _=T.check("stream.take-zero/demand",fn()=>BenchStream.take 0 mapped=[] andalso !spineCalls=0)
  val _=T.check("stream.spine/head-not-forced",fn()=>
    (case BenchLazy.force mapped of BenchStream.Cons _=>true|_=>false) andalso !headCalls=0)
  val _=T.check("stream.take-one/tail-not-forced",fn()=>BenchStream.take 1 mapped=[17] andalso !tailCalls=0)
  val _=T.check("stream.head/sharing",fn()=>BenchStream.head mapped=17 andalso !spineCalls=1 andalso !headCalls=1)
  val producerCalls=ref 0
  val ones=BenchStream.fix(fn self=>(producerCalls := !producerCalls+1;
    BenchStream.Cons(BenchLazy.delay(fn()=>1),self)))
  val _=T.check("stream.recursive/shared-spine",fn()=>BenchStream.take 6 ones=[1,1,1,1,1,1] andalso !producerCalls=1)
  exception Problem
  val failureCalls=ref 0
  val bad : int BenchLazy.delay = BenchLazy.delay(fn()=>(failureCalls := !failureCalls+1;raise Problem))
  fun rejected()=(BenchLazy.force bad;false)handle Problem=>true
  val _=T.check("stream.exception/shared",fn()=>rejected() andalso rejected() andalso !failureCalls=1)
  val rightCalls=ref 0
  val right=BenchLazy.delay(fn()=>(rightCalls := !rightCalls+1;
    BenchStream.Cons(BenchLazy.delay(fn()=>19),BenchStream.empty())))
  val joined=BenchStream.append(BenchStream.singleton 7)right
  val _=T.check("stream.append/right-demand",fn()=>BenchStream.take 1 joined=[7] andalso !rightCalls=0)
  val _=T.check("stream.append/boundary",fn()=>BenchStream.take 2 joined=[7,19] andalso !rightCalls=1)
  val predicateCalls=ref 0
  val counting=BenchStream.iterate(fn n=>n+1)(BenchLazy.delay(fn()=>1))
  val(prefix,suffix)=BenchStream.span(fn n=>(predicateCalls := !predicateCalls+1;n<3))counting
  val _=T.check("stream.span/prefix-demand",fn()=>BenchStream.take 1 prefix=[1] andalso !predicateCalls=1)
  val _=T.check("stream.span/split-sharing",fn()=>BenchStream.head suffix=3 andalso
    BenchStream.take 2 prefix=[1,2] andalso !predicateCalls=3)
  val folded=BenchStream.foldrStream(fn(x,_)=>BenchStream.singleton x)(BenchStream.empty())source
  val _=T.check("stream.foldr/ignored-tail",fn()=>BenchStream.head folded=13 andalso !tailCalls=0)
end
