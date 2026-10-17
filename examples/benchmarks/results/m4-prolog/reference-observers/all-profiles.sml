structure Need=BenchPrologFn(BenchNeed)
structure Strict=BenchPrologFn(BenchStrict)
structure K=Need
structure Main=
struct
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  val base="tests/out/benchmarks/prolog-originals/"
  val lib=K.readLibrary(read(base^"source/runtime_files/stdlib"))
  val db=List.foldl(fn(clause,db)=>K.addClause db clause)K.emptyDb lib
  fun text chars=String.implode(List.rev(BenchStream.foldl(fn(c,cs)=>c::cs)[]chars))
  fun run(engine,prove,file,profile)=
    let val output=text(K.interactive prove db(String.explode(read(base^"source/"^file))))
        val file=TextIO.openOut(base^"pilot-"^engine^"-"^profile^".text")
        val _=TextIO.output(file,output)val _=TextIO.closeOut file
    in print(engine^" "^Int.toString(String.size output)^"\n")end
  val _=List.app(fn(profile,file)=>
    (run("stack",K.proveStack,file,profile);run("pure",K.proveTree,file,profile)))
    [("smoke","prolog.faststdin"),("normal","prolog.stdin"),("large","prolog.slowstdin")]
end
structure MainStrict=
struct
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  structure K=Strict
  val base="tests/out/benchmarks/prolog-originals/"
  val lib=K.readLibrary(read(base^"source/runtime_files/stdlib"))
  val db=List.foldl(fn(clause,db)=>K.addClause db clause)K.emptyDb lib
  fun text chars=String.implode(List.rev(BenchStream.foldl(fn(c,cs)=>c::cs)[]chars))
  fun run(engine,prove,file,profile)=
    let val output=text(K.interactive prove db(String.explode(read(base^"source/"^file))))
        val file=TextIO.openOut(base^"pilot-strict-"^engine^"-"^profile^".text")
        val _=TextIO.output(file,output)val _=TextIO.closeOut file
    in print(engine^" "^Int.toString(String.size output)^"\n")end
  val _=List.app(fn(profile,file)=>
    (run("stack",K.proveStack,file,profile);run("pure",K.proveTree,file,profile)))
    [("smoke","prolog.faststdin"),("normal","prolog.stdin"),("large","prolog.slowstdin")]
end
