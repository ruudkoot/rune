from pathlib import Path
p=Path(__file__).resolve().parent
body=r'''
structure KernelPOLICY=BenchMkhprogFn(BenchPOLICY)
structure DriverPOLICY=BenchMkhprogDriverFn(KernelPOLICY)
structure TestsPOLICY=struct
 structure K=KernelPOLICY
 structure Driver=DriverPOLICY
 structure D=BenchPOLICY
 structure W=Word64
 val base="BASE/"
 fun read name=Driver.read(base^name)
 fun label s="mkhprog/POLICY/"^s
 fun collect name=
   let val result=ref[]
       fun emit(target,text)=result:=((case target of K.Hashed=>"-"|K.File name=>name|K.Usage=>"usage"),
         K.toString text,K.hash text):: !result
       val _=if name="aux"then K.aux K.stop{literate=false,moduleName="Main",target=K.Hashed,emit=emit}
         else K.run(K.normalized(read(name^".input")))emit
   in List.rev(!result)end
 fun check name=
   let val rows=collect name
       val expected=Driver.reference(read(name^".hashes"))
       val channels=String.tokens(fn c=>c= #"\n")(read(name^".channels"))
   in
     T.check(label(name^"-full-text"),fn()=>String.concat(List.map #2 rows)=read(name^".text"));
     T.check(label(name^"-block-hashes"),fn()=>List.map #3 rows=
       Vector.foldr(op ::)[]expected);
     T.check(label(name^"-channels"),fn()=>List.map #1 rows=channels)
   end
 val _=List.app check["default","aux","empty","one-int","boolean","string","literate","module-inline","file"]
 val _=List.app(fn name=>T.check(label(name^"-usage"),fn()=>
   case collect name of [("usage",text,_)]=>text=read(name^".usage")|_=>false))
   ["duplicate","toggle-duplicate","odd","plus-non-bool","short-flag","long-flag","bad-literate"]
 val wanted=Driver.reference(read"default.hashes")
 val input=K.normalized(read"default.input")
 val _=T.check(label"normalized-input-keeps-word-order",fn()=>K.normalized" -a  Int\n-b\tBool\n"="-a\nInt\n-b\nBool\n")
 val _=T.check(label"input-normalization-is-idempotent",fn()=>K.normalized input=input)
 val _=T.check(label"all-62-blocks-are-consumed",fn()=> #1(Driver.checked input wanted)=62)
 val _=T.check(label"corrupt-block-reference-is-rejected",fn()=>
   let val wrong=Vector.tabulate(Vector.length wanted,fn i=>
         if i=0 then W.+(Vector.sub(wanted,i),0w1)else Vector.sub(wanted,i))
   in ((Driver.checked input wrong;false)handle Fail _=>true)end)
 val _=T.check(label"missing-block-reference-is-rejected",fn()=>
   ((Driver.checked input(Vector.tabulate(Vector.length wanted-1,fn i=>Vector.sub(wanted,i)));false)handle Fail _=>true))
 val _=T.check(label"extra-block-reference-is-rejected",fn()=>
   ((Driver.checked input(Vector.tabulate(Vector.length wanted+1,fn i=>
       if i=Vector.length wanted then 0w0 else Vector.sub(wanted,i)));false)handle Fail _=>true))
 val _=T.check(label"usage-cannot-supply-timings",fn()=>
   ((Driver.checked(K.normalized(read"duplicate.input"))wanted;false)handle Fail _=>true))
 val _=T.check(label"file-output-is-outside-hashed-stdout-profile",fn()=>
   ((Driver.checked(K.normalized(read"file.input"))wanted;false)handle Fail _=>true))
 val _=List.app(fn text=>T.check(label("bad-reference-"^text),fn()=>
   ((Driver.reference text;false)handle Fail _=>true)))["-1","18446744073709551616","not-a-word"]
 val _=List.app(fn(text,wanted)=>T.check(label("hash-"^text),fn()=>K.hash(K.literal text)=W.fromInt wanted))
   [("",0),("a",97),("abc",96354)]
 val _=T.check(label"empty-argument-range",fn()=>K.toString(K.args 2 1)="")
 val _=T.check(label"argument-range-is-inclusive",fn()=>K.toString(K.args 2 4)=" x2 x3 x4")
 val _=T.check(label"literal-prefix-includes-each-line",fn()=>K.toString(K.lit(K.literal"a\nb\n"))="> a\n> b\n> ")
 val _=T.check(label"zero-repetitions",fn()=>Driver.run["0",base^"default.input",base^"default.hashes"]="0:0:0")
 val _=T.check(label"repetition-reset",fn()=>
   let val first=Driver.run["1",base^"default.input",base^"default.hashes"]
       val second=Driver.run["2",base^"default.input",base^"default.hashes"]
       val (_,value)=Driver.checked input wanted
   in first="1:62:"^W.toString value andalso second="2:124:"^W.toString(W.+(value,value))end)
 exception Stop
 val _=T.check(label"continuation-output-can-stop-at-first-block",fn()=>
   let val calls=ref 0
       fun emit(_,_)=(calls:= !calls+1;raise Stop)
   in ((K.run input emit;false)handle Stop=> !calls=1)end)
end
'''
s=''.join(body.replace('POLICY',policy).replace('BASE',str(p))for policy in ['Need','Strict'])
s+=r'''
structure Demand=struct
 structure K=KernelNeed
 structure Q=KernelStrict
 exception Stop
 val _=T.check("mkhprog/lazy-type-text-is-not-demanded-by-header",fn()=>
   let val calls=ref 0
       val typ=K.delay(fn()=>(calls:= !calls+1;K.literal"Int"))
       fun emit(_,_) = raise Stop
   in ((K.generate[("-a",typ)]{literate=false,moduleName="Main",target=K.Hashed,emit=emit};false)
       handle Stop=> !calls=0)end)
 val _=T.check("mkhprog/strict-type-text-is-materialized-before-output",fn()=>
   let val calls=ref 0
       val typ=Q.delay(fn()=>(calls:= !calls+1;Q.literal"Int"))
       fun emit(_,_) = raise Stop
   in ((Q.generate[("-a",typ)]{literate=false,moduleName="Main",target=Q.Hashed,emit=emit};false)
       handle Stop=> !calls=1)end)
 val _=T.check("mkhprog/literal-comparison-does-not-force-mismatching-tail",fn()=>
   let val tail=BenchNeed.delay(fn()=>raise Fail "unused type suffix")
       val typ=BenchNeed.delay(fn()=>K.Cons(#"F",tail))
   in K.toString(K.defaultArg typ)=" ??"end)
 val _=T.check("mkhprog/lazy-text-is-shared-by-two-consumers",fn()=>
   let val calls=ref 0
       val text=K.delay(fn()=>(calls:= !calls+1;K.literal"abc"))
       val delayed= !calls=0
       val hash=K.hash text val output=K.toString text
   in delayed andalso hash=0w96354 andalso output="abc"andalso !calls=1 end)
end
'''
(p/'tests.sml').write_text('(* Crown Copyright 1992. Source behavior of N. D. Norths parser generator. *)\n'+s)
