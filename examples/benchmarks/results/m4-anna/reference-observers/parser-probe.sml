fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor ParserTests(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchAnnaFn(D)
 val p="tests/out/benchmarks/nofib-anna-originals/"
 fun one(profile,file)=let val source=read(p^"source/"^file)
      val value=K.parseSyntax(K.lex(K.int 1)(K.input source))
      val _=K.parseCore(K.input source)
      val(types,_)=D.force value
      val groups=K.typeDependency types
      val grouping=K.showList(fn(recursive,names)=>"("^(if D.force recursive then"True"else"False")^","^K.namesShown names^")")groups
      val groupingExpected=read(p^"dependency-"^profile^".reference")
      val _=if grouping=groupingExpected then print("PASS "^label^" complete type dependencies "^profile^"\n")else raise Fail"type dependencies"
      val actual=K.observeProgram value
      val expected=read(p^"parsed-"^profile^".reference")
   in if actual=expected then print("PASS "^label^" full parsed "^profile^"\n")
     else let val out=TextIO.openOut(p^"parsed-"^profile^"-"^label^".actual")
        in TextIO.output(out,actual);TextIO.closeOut out;raise Fail"parsed Core"end end
 val _=List.app one[("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
 val table=K.readTable(K.input(read(p^"source/runtime_files/anna_table")))
 val actual=K.observeTable table
 val expected=read(p^"lattice-table.reference")
 val _=if actual=expected then print("PASS "^label^" complete lattice table\n")
   else let val out=TextIO.openOut(p^"lattice-table-"^label^".actual")
      in TextIO.output(out,actual);TextIO.closeOut out;raise Fail"lattice table"end
end
structure Need=ParserTests(structure D=BenchNeed val label="lazy")
structure Strict=ParserTests(structure D=BenchStrict val label="strict")
