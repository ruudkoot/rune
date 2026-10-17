from pathlib import Path
p=Path(__file__).resolve().parent
body=r'''
structure CorePOLICY=BenchGGCoreFn(BenchPOLICY)
structure ProbePOLICY=struct
 structure K=CorePOLICY
 structure D=BenchPOLICY
 structure S=BenchStream
 structure L=BenchLazy
 val base="BASE/"
 fun read file=let val f=TextIO.openIn file val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
 fun show n=IntInf.toString(D.force n)
 fun row(K.Ln(pe,act,spark))=
      let val K.PE(name,no)=L.force pe
      in String.concatWith " "(String.implode name::show no::
         List.map show(K.actValues(L.force act)@K.sparkValues(L.force spark)))end
   |row _=raise Fail "unexpected ordered line"
 fun check(profile,input)=
   let val input=String.explode(read(base^"source/"^input))
       val(pes,ticks,ordered)=L.force(K.parameters(K.parseFile input))
       val actual=String.concat(List.rev(S.foldl(fn(line,rows)=>(row line^"\n")::rows)[]ordered))
       val wanted=read(base^profile^".rows")
       val _=if actual=wanted then()else
         let val file=TextIO.openOut(base^"actual-POLICY-"^profile^".rows")
             val _=TextIO.output(file,actual)val _=TextIO.closeOut file
         in raise Fail("incorrect parsed or ordered GRIP rows "^profile)end
       val count=S.foldl(fn(_,n)=>n+1)0 pes
   in print("POLICY "^profile^" "^Int.toString count^" "^show ticks^" OK\n")end
 val _=List.app check[("smoke","gg.faststdin"),("normal","gg.stdin"),("large","gg.slowstdin")]
end
'''
(p/'core-pilot.sml').write_text(''.join(body.replace('POLICY',policy).replace('BASE',str(p))for policy in ['Need','Strict']))
