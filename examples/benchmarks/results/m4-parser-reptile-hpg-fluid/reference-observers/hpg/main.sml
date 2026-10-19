 fun finish env=()
 fun printStr chars k=getOutput(fn out=>fn env=>(out chars;k env))
 fun printTest expressions=let
     fun pair p=B.delayed(fn()=>let val(name,e)=force p
       in B.pieces[showName name,B.literal" == ",showExpression 0 e]end)
     val out=B.output(B.pieces[B.literal"main = print [",sep ", "pair expressions,B.literal"]\n}"])
   in printStr(splitStr 70 out)finish end
 fun printProgram expressions=allTypes(fn types=>allValues(fn values=>
   let val builders=F.append(map(fn t=>scalar(showTypeDecl t))types)(map(fn v=>scalar(showValDecl v))values)
       val out=B.output(B.cat(sep ";\n"force builders)(B.literal";\n"))
   in printStr(splitStr 70 out)(printTest expressions)end))
 fun generate seeds nt dt nv dv de moduleName output=
   let val(a,b,c)=seeds
       val shownSeeds="("^number a^","^number b^","^number c^")"
       val header=B.output(B.pieces[
         B.literal"-- HPG version 1.20 dated 92/07/20\n-- Output from hpg ",
         B.literal(String.concatWith " "[shownSeeds,number nt,number dt,number nv,number dv,number de]),
         B.literal"\n-- Random number generator seeds: ",B.literal shownSeeds,
         B.literal"\n-- ",B.literal(number nt),B.literal" types, of depth ",B.literal(number dt),
         B.literal"\n-- ",B.literal(number nv),B.literal" values, of depth ",B.literal(number dv),
         B.literal"\n-- Expression depth: ",B.literal(number de),
         B.literal"\n\nmodule ",B.literal moduleName,B.literal" (main) where {\n\n"])
   in printStr header(genTypes 6 4 nt dt
         (genValues nv dv(genExpressions de printProgram)))(makeEnv seeds output)end
 fun hash chars=let fun loop h chars=case BenchNeed.force chars of C.Nil=>h
      |C.Cons(c,rest)=>loop(Word64.+(Word64.*(h,0w31),Word64.fromInt(Char.ord(L.force c))))rest
   in loop 0w0 chars end
 fun signedHash word=let val n=Word64.toLargeInt word
     val n=if Word64.andb(word,0wx8000000000000000)=0w0 then n else n-18446744073709551616
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString n)end
