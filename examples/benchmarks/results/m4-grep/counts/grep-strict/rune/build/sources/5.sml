(* Strict UTF-8 acquisition for Haskell Char inputs; Unicode scalar integers. *)
structure BenchUTF8 =
struct
 fun decode bytes =
  let val size=String.size bytes
      fun byte i=if i<size then Char.ord(String.sub(bytes,i))else raise Fail "truncated UTF-8"
      fun continuation i=let val b=byte i in if b>=128 andalso b<192 then b-128 else raise Fail "invalid UTF-8 continuation"end
      fun loop i=if i=size then []else
        let val b=byte i
            val(code,next)=if b<128 then(b,i+1)
              else if b>=194 andalso b<224 then((b-192)*64+continuation(i+1),i+2)
              else if b>=224 andalso b<240 then
                let val c=(b-224)*4096+continuation(i+1)*64+continuation(i+2)
                in if c>=2048 andalso not(c>=55296 andalso c<=57343)then(c,i+3)else raise Fail "invalid UTF-8 scalar"end
              else if b>=240 andalso b<245 then
                let val c=(b-240)*262144+continuation(i+1)*4096+continuation(i+2)*64+continuation(i+3)
                in if c>=65536 andalso c<=1114111 then(c,i+4)else raise Fail "invalid UTF-8 scalar"end
              else raise Fail "invalid UTF-8 leading byte"
        in code::loop next end
  in loop 0 end
 fun lines codes =
   let fun next []=[]
         | next xs=let fun line [] reverse=(List.rev reverse,[])
                        | line(10::rest)reverse=(List.rev reverse,rest)
                        | line(c::rest)reverse=line rest(c::reverse)
                      val(first,rest)=line xs[]
                  in first::next rest end
   in next codes end
end
