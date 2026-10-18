fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor CodegenProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D) structure L=BenchLazy structure F=K.F
 fun one name=
  let val root="tests/out/benchmarks/nofib-happy-originals/"
      val(warnings,output)=K.generate(read(root^"grammar-data/"^name^".input"))
      val expectedWarnings=read(root^"end-to-end-data/"^name^"/stderr")
      val _=if String.implode(F.toList warnings)=expectedWarnings then()
          else raise Fail(label^" "^name^": warnings differ")
      val expected=read(root^"codegen-data/"^name^".reference")
      fun loop index chars=case D.force chars of F.Nil=>
            if index=String.size expected then index else raise Fail("short output at "^Int.toString index)
         |F.Cons(value,rest)=>if index>=String.size expected then raise Fail("long output at "^Int.toString index)
            else if D.force value=String.sub(expected,index)then loop(index+1)rest
            else raise Fail("different output at "^Int.toString index^" expected "^Int.toString(Char.ord(String.sub(expected,index)))^" got "^Int.toString(Char.ord(D.force value)))
      val count=(loop 0 output handle Fail message=>
          let val f=TextIO.openOut(root^"codegen-data/"^name^"-"^label^".actual")
              fun write chars=case D.force chars of F.Nil=>()|F.Cons(value,rest)=>
                   (TextIO.output1(f,D.force value);write rest)
          in write output;TextIO.closeOut f;raise Fail(label^" "^name^": "^message)end)
  in print("PASS "^label^" "^name^" "^Int.toString count^" bytes\n")end
 val _=List.app one ["basic","precedence","typed","multiple-starts","quote-normalization","attributes","attribute-groups","attribute-rightmost","attribute-zero","attribute-empty","monad-lexer","default"]
end
structure NeedCodegen=CodegenProbeFn(structure D=BenchNeed val label="need")
structure StrictCodegen=CodegenProbeFn(structure D=BenchStrict val label="strict")
