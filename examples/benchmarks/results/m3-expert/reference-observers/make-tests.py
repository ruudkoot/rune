from pathlib import Path
p=Path(__file__).resolve().parent;root=Path.cwd()
s='''functor ExpertTestsFn(P:sig val eagerTerms:bool val policy:string end)=struct
 structure App=BenchExpertFn(P)
 structure K=App.K
 structure Driver=BenchExpertDriverFn(App)
 open K
 val base="BASE"
 val animals=Driver.read(base^"source/runtime_files/animals")
 fun label s="expert/"^P.policy^"/"^s
 fun render xs=String.implode(rev(S.foldl(fn(c,cs)=>c::cs)[]xs))
 val _=List.app(fn name=>T.check(label("original dialog "^name),fn()=>
     render(App.processText animals(Driver.read(base^"cases/"^name^".input")))=
       Driver.read(base^"cases/"^name^".output")))
     ["source","lower-no","uppercase-no","all-yes","stop-first","mixed"]
 fun lookup table key=case L.force(find table key)of Reason _=>NONE|Answer value=>SOME(L.force value)
 fun entry(k,v)=(L.delay(fn()=>k),L.delay(fn()=>v))
 val _=T.check(label "lazy table first duplicate wins",fn()=>
   lookup(enterList(newTable())(S.fromList[entry("x",1),entry("x",2)]))"x"=SOME 1)
 val _=T.check(label "updateList last new duplicate wins",fn()=>
   lookup(updateList(newTable())(S.fromList[entry("x",1),entry("x",2)]))"x"=SOME 2)
 val _=T.check(label "single update replaces value",fn()=>
   lookup(update(enter(newTable())"x"(L.delay(fn()=>1)))"x"(L.delay(fn()=>2)))"x"=SOME 2)
 val _=T.check(label "enter retains old value",fn()=>
   lookup(enter(enter(newTable())"x"(L.delay(fn()=>1)))"x"(L.delay(fn()=>2)))"x"=SOME 1)
 val _=T.check(label "lookup avoids unused table branch",fn()=>
   let val tree=L.delay(fn()=>Fork(L.delay(fn()=>raise Fail "unused left"),entry("x",3),
         L.delay(fn()=>raise Fail "unused right")))
   in lookup tree "x"=SOME 3 end)
 val _=T.check(label "unification and substitution",fn()=>
   let val a=relation["X","has","stripes"]val b=relation["the","animal","has","Y"]
   in case match(newTable())a b of Reason _=>false|Answer env=>
      showPhrase(subst env(variable"X"))="the animal"andalso showPhrase(subst env(variable"Y"))="stripes"end)
 val _=T.check(label "occurs check rejects self reference",fn()=>
   case match(newTable())(variable"X")(term"has"(S.fromList[variable"X",term"stripes"(S.empty())]))of
      Reason why=>why="occurs check failed"|_=>false)
 val _=T.check(label "term mismatch fails",fn()=>case match(newTable())
   (term"zebra"(S.empty()))(term"tiger"(S.empty()))of Reason why=>why="no match"|_=>false)
 val _=T.check(label "source zip truncates unmatched phrase arity",fn()=>case match(newTable())
   (term"same"(S.empty()))(term"same"(S.singleton(variable"X")))of Answer _=>true|_=>false)
 val _=T.check(label "question precedes missing answer",fn()=>
   let val info=L.delay(fn()=>raise Fail "answer forced")
       val soln=App.Soln(newTable(),App.names 0)
       val stream=App.ask info soln(relation["the","animal","has","stripes"])
   in case S.head stream of App.Question q=>q="the animal has stripes"|_=>false end)
 val _=T.check(label "lookup only when answer demanded",fn()=>
   let val stream=App.ask(L.delay(fn()=>raise Fail "answer forced"))
       (App.Soln(newTable(),App.names 0))(relation["the","animal","has","stripes"])
   in ((L.force(S.tail stream);false)handle Fail why=>why="answer forced")end)
 val _=T.check(label "unused answer stream remains unforced",fn()=>
   let val input=S.append(S.fromList(String.explode "yes\\nyes\\nno\\n"))(L.delay(fn()=>raise Fail "unused answers"))
   in render(App.process animals input)=Driver.read(base^"cases/stop-first.output")end)
 val _=T.check(label "driver repeats source prefix and dialog",fn()=>
   Driver.run["2",base^"source/runtime_files/animals",base^"source/expert.stdin",base^"cases/source.output"]="2 1052")
 val _=T.check(label "zero repetitions",fn()=>
   Driver.run["0",base^"source/runtime_files/animals",base^"source/expert.stdin",base^"cases/source.output"]="0 0")
 val _=T.check(label "incorrect dialog rejected",fn()=>
   ((Driver.consume "wrong"(App.processText animals(Driver.read(base^"source/expert.stdin")));false)
     handle Fail why=>String.isPrefix "incorrect result:"why))
end
structure LazyExpertTests=ExpertTestsFn(struct val eagerTerms=false val policy="lazy"end)
structure StrictExpertTests=ExpertTestsFn(struct val eagerTerms=true val policy="strict"end)
'''.replace('BASE',str(p)+'/')
(p/'tests.sml').write_text(s)
files=[root/'tests/basis/harness.sml']+[root/'examples/benchmarks/shared'/x for x in ['input.sml','lazy.sml','stream.sml']]+[p/x for x in ['table.sml','phrase.sml','program.sml','driver.sml','tests.sml']]+[root/'tests/basis/finish.sml']
(p/'test-sources.txt').write_text(''.join(str(f)+'\n'for f in files))
