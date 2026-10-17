structure Probe=struct
 structure C=BenchGGCheck
 structure S=BenchStream
 fun attempt name thunk=
   ((print(name^" "^Int.toString(thunk())^"\n"))
    handle e=>print(name^" exception "^General.exnName e^" "^General.exnMessage e^"\n"))
 val _=attempt"empty"(fn()=>C.consume(S.empty())[])
 val _=attempt"line"(fn()=>C.consume(S.fromList(String.explode"stroke\n"))(C.rows"stroke\n"))
 val _=attempt"numeric"(fn()=>C.consume(S.fromList(String.explode"1.5000000000 2.0 scale\n"))(C.rows"1.5 2.0 scale\n"))
 val _=print("zero-equality "^Bool.toString((0w0:Word64.word)=(0w0:Word64.word))^"\n")
 val _=T.check("probe/completed",fn()=>true)
end
