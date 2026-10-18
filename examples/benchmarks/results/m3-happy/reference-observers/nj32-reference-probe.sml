structure K=BenchHappyFn(BenchNeed)
fun probe name thunk=(print(name^": "^thunk()^"\n")
 handle e=>print(name^": "^General.exnName e^" "^General.exnMessage e^"\n"))
val _=probe"Int.maxInt"(fn()=>case Int.maxInt of NONE=>"none"|SOME n=>Int.toString n)
val _=probe"guard constant"(fn()=>Int.toString((1073741823-1)div 10))
val _=probe"readReference"(fn()=>case K.readReference(K.X.text"1")of NONE=>"none"|SOME(n,_)=>Int.toString n)
val _=probe"doCheckCode"(fn()=>case K.doCheckCode 1(K.X.text"$1")of K.Rejected _=>"errors"
  |K.Succeeded value=>let val(code,used)=BenchLazy.force value in K.X.string code end)
val _=probe"no reference"(fn()=>case K.doCheckCode 1(K.X.text"x")of K.Rejected _=>"errors"
  |K.Succeeded value=>let val(code,used)=BenchLazy.force value in K.X.string code end)
fun bound(base,n)=(1073741823-n)div base
fun product(value,base,n)=value*base+n
val base=valOf(Int.fromString"10")
val value=valOf(Int.fromString"0")
val digit=valOf(Int.fromString"1")
val _=probe"dynamic guard"(fn()=>Int.toString(bound(base,digit)))
val _=probe"dynamic product"(fn()=>Int.toString(product(value,base,digit)))
val _=probe"literal digit"(fn()=>case K.digit base #"1"of NONE=>"none"|SOME n=>Int.toString n)
val _=probe"literal uncons"(fn()=>case K.uncons(K.X.text"1")of NONE=>"none"|SOME(c,_)=>Char.toString c)
fun readSimple chars=
 let fun collect base value count chars=case chars of []=>SOME(value,count)
       |c::rest=>(case K.digit base c of NONE=>NONE|SOME n=>
         if value>(1073741823-n)div base then NONE else collect base(value*base+n)(count+1)rest)
 in case collect 10 0 0 chars of NONE=>"none"|SOME(n,_)=>Int.toString n end
val _=probe"simple collect"(fn()=>readSimple[#"1"])
val _=print"SUMMARY 0 checks, 0 failed\n"
