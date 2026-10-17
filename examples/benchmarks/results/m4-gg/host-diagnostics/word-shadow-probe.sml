structure Probe=struct
 structure W=Word64
 fun plain count (forward:W.word) (combined:W.word)=
   if forward<>combined then raise Fail "plain unequal"else count
 fun shadow count (forward:W.word) (combined:W.word)=
   let val(count,combined,wanted)=(count,combined,[]:int list)
   in if not(List.null wanted)then raise Fail "wanted"
      else if forward<>combined then raise Fail "shadow unequal"else count end
 fun tuple count (forward:W.word) (combined:W.word) condition=
   let val(count,combined,wanted)=if condition then(count,combined,[]:int list)
       else(count+1,Word64.+(combined,0w0),[]:int list)
   in if not(List.null wanted)then raise Fail "wanted"
      else if forward<>combined then raise Fail "tuple unequal"else count end
 fun attempt name thunk=
  ((print(name^" "^Int.toString(thunk())^"\n"))
    handle e=>print(name^" exception "^General.exnMessage e^"\n"))
 val _=attempt"plain-zero"(fn()=>plain 0 0w0 0w0)
 val _=attempt"shadow-zero"(fn()=>shadow 0 0w0 0w0)
 val _=attempt"tuple-zero"(fn()=>tuple 0 0w0 0w0 true)
 val _=attempt"tuple-branch-zero"(fn()=>tuple 0 0w0 0w0 false)
 val _=attempt"plain-large"(fn()=>plain 0 0wx123456789ABCDEF0 0wx123456789ABCDEF0)
 val _=attempt"shadow-large"(fn()=>shadow 0 0wx123456789ABCDEF0 0wx123456789ABCDEF0)
 val _=T.check("word-probe/completed",fn()=>true)
end
