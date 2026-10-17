structure Probe =
struct
 structure W=Word64
 fun broken(input:char list)(wanted:int list)(buffer:char list) count
     (forward:W.word)(combined:W.word)=
   case input of []=>
     let val(count,combined,wanted)=
           if List.null buffer then(count,combined,wanted)
           else(count+1,W.+(combined,0w0),wanted)
     in if not(List.null wanted)then raise Fail "wanted"
        else if forward<>combined then raise Fail "unequal Word64 arguments"
        else count end
   |first::rest=>broken rest wanted(first::buffer)count
       (W.+(W.*(forward,0w31),W.fromInt(Char.ord first)))
       (W.+(W.*(combined,0w31),W.fromInt(Char.ord first)))
 fun plain(input:char list)(wanted:int list)(buffer:char list) count
     (forward:W.word)(combined:W.word)=
   case input of []=>if forward<>combined then raise Fail "plain unequal"else count
   |first::rest=>plain rest wanted(first::buffer)count
       (W.+(W.*(forward,0w31),W.fromInt(Char.ord first)))
       (W.+(W.*(combined,0w31),W.fromInt(Char.ord first)))
 val _=T.check("word-recursive-tuple/plain",fn()=>plain[][][]0 0w0 0w0=0)
 val _=T.check("word-recursive-tuple/empty",fn()=>broken[][][]0 0w0 0w0=0)
 val _=T.check("word-recursive-tuple/line",fn()=>broken(String.explode"x")[][]0 0w0 0w0=1)
end
