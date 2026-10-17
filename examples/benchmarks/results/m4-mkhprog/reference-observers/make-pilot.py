from pathlib import Path
p=Path(__file__).resolve().parent
body=r'''
structure KernelPOLICY=BenchMkhprogFn(BenchPOLICY)
structure PilotPOLICY=struct
 structure K=KernelPOLICY
 structure D=BenchPOLICY
 val base="BASE/"
 fun read file=let val f=TextIO.openIn file val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
 fun check name=
  let val output=ref[]
      fun emit(target,text)=
        let val channel=case target of K.Hashed=>"-"|K.File f=>f|K.Usage=>"usage"
        in output:=(channel,K.toString text,K.hash text):: !output end
      val _=if name="aux"then K.aux K.stop{literate=false,moduleName="Main",target=K.Hashed,emit=emit}
            else K.run(K.normalized(read(base^name^".input")))emit
      val rows=List.rev(!output)
      val expectedText=read(base^name^".text")
      val expectedHashes=List.map(fn x=>Word64.fromLargeInt(valOf(IntInf.fromString x)))
        (String.tokens Char.isSpace(read(base^name^".hashes")))
      val channels=String.tokens(fn c=>c= #"\n")(read(base^name^".channels"))
      val _=if String.concat(List.map #2 rows)=expectedText then()else raise Fail("wrong text "^name)
      val _=if List.map #3 rows=expectedHashes then()else raise Fail("wrong hashes "^name)
      val _=if List.map #1 rows=channels then()else raise Fail("wrong channels "^name)
  in print("POLICY "^name^" "^Int.toString(List.length rows)^" OK\n")end
 val _=List.app check["default","aux","empty","one-int","boolean","string","literate","module-inline","file"]
end
'''
(p/'pilot.sml').write_text(''.join(body.replace('POLICY',policy).replace('BASE',str(p))for policy in ['Need','Strict']))
