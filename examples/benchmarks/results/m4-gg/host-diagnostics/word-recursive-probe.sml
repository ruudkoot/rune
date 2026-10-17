structure Probe =
struct
 structure W=Word64
 fun pair (a:W.word)(b:W.word)(input:int list)=case input of
   []=>a=b|_::rest=>pair a b rest
 fun interleaved(input:int list) count (a:W.word)(b:W.word)=case input of
   []=>a=b|_::rest=>interleaved rest(count+1)a b
 fun many(input:int list)(unused:int list)(buffer:int list) count (a:W.word)(b:W.word)=
   case input of []=>a=b|x::rest=>many rest unused(x::buffer)(count+1)a b
 val _=T.check("word-recursive/pair-zero",fn()=>pair 0w0 0w0[])
 val _=T.check("word-recursive/pair-large",fn()=>pair 0wx123456789ABCDEF0 0wx123456789ABCDEF0[])
 val _=T.check("word-recursive/interleaved-zero",fn()=>interleaved[]0 0w0 0w0)
 val _=T.check("word-recursive/many-zero",fn()=>many[][][]0 0w0 0w0)
 val _=T.check("word-recursive/many-large",fn()=>many[][][]0 0wx123456789ABCDEF0 0wx123456789ABCDEF0)
end
