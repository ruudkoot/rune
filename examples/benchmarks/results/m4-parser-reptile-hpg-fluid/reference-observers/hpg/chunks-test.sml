functor Chunks(D:BENCH_SUSPEND)=struct
 structure K=BenchHpgFn(D)
 fun test(name,nt,dt,nv,dv,de)=
   let val index=ref 0
       fun output chars=let
         val path="tests/out/benchmarks/nofib-hpg-originals/"^name^"-chunk-"^Int.toString(!index)^".reference"
         val file=TextIO.openIn path val expected=TextIO.inputAll file val _=TextIO.closeIn file
         val actual=K.string chars
         val _=if actual=expected then()else
          let val f=TextIO.openOut("tests/out/benchmarks/nofib-hpg-originals/mismatch-"^name^"-"^Int.toString(!index)^".sml-output")
          in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("HPG mismatch "^name^" chunk "^Int.toString(!index))end
         in print("PASS "^name^" complete source chunk "^Int.toString(!index)^" ("^Int.toString(size actual)^" bytes)\n");TextIO.flushOut TextIO.stdOut;index:= !index+1 end
   in K.generate(9807,65,32975)nt dt nv dv de "Main"output
      ;if !index=3 then()else raise Fail"three source chunks"end
 val _=List.app test[("smoke",8,4,10,6,6),("normal",40,5,60,6,6),("large",80,8,100,8,8)]
end
structure A=Chunks(BenchNeed)
structure B=Chunks(BenchStrict)
