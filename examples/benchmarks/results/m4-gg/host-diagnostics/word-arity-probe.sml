structure Probe=struct
 structure W=Word64
 fun six (a:int list)(b:int list)(c:int list) count (forward:W.word)(combined:W.word)=
   if forward<>combined then raise Fail "six unequal"else count
 fun recursive (a:char list)(b:int list)(buffer:char list) count (forward:W.word)(combined:W.word)=
   case a of []=>
     let val(count,combined,b)=if List.null buffer then(count,combined,b)
         else(count+1,W.+(combined,0w0),b)
     in if not(List.null b)then raise Fail "wanted"
        else if forward<>combined then raise Fail "recursive unequal"else count end
   |first::rest=>recursive rest b(first::buffer)count
       (W.+(W.*(forward,0w31),W.fromInt(Char.ord first)))
       (W.+(W.*(combined,0w31),W.fromInt(Char.ord first)))
 fun attempt name thunk=
   ((print(name^" "^Int.toString(thunk())^"\n"))
     handle e=>print(name^" exception "^General.exnMessage e^"\n"))
 val _=attempt"six-zero"(fn()=>six[][][]0 0w0 0w0)
 val _=attempt"six-large"(fn()=>six[][][]0 0wx123456789ABCDEF0 0wx123456789ABCDEF0)
 val _=attempt"recursive-zero"(fn()=>recursive[][][]0 0w0 0w0)
 val _=attempt"recursive-line"(fn()=>recursive(String.explode"stroke\n")[][]0 0w0 0w0)
 val _=T.check("word-arity/completed",fn()=>true)
end
