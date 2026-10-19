functor BenchHiddenParseFn(K:sig
 type number
 type vector
 structure N:sig val literal:real->number end
 val vec:number list->vector
end) =
struct
  structure L=BenchLazy
  structure S=BenchStream
  datatype token=Left|Right|Comma|Vec|Number of real
  fun tokenize text=
    let val size=String.size text
        fun numeric c=Char.isDigit c orelse c= #"."orelse c= #"-"orelse c= #"+"orelse c= #"~"orelse c= #"e"orelse c= #"E"
        fun take i=if i<size andalso numeric(String.sub(text,i))then take(i+1)else i
        fun loop i=if i=size then[]else
          let val c=String.sub(text,i)
          in if Char.isSpace c then loop(i+1)
             else if c= #"["then Left::loop(i+1)
             else if c= #"]"then Right::loop(i+1)
             else if c= #","then Comma::loop(i+1)
             else if i+3<=size andalso String.substring(text,i,3)="vec"then Vec::loop(i+3)
             else if numeric c then
               let val after=take i val part=String.substring(text,i,after-i)
               in case Real.fromString part of SOME value=>
                    if Real.isFinite value then Number value::loop after else raise Fail "nonfinite hidden input"
                  |NONE=>raise Fail "invalid hidden number"end
             else raise Fail "invalid hidden token"end
    in loop 0 end
  fun point tokens=
    let fun components(Number n::Comma::rest,values)=components(rest,K.N.literal n::values)
          |components(Number n::Right::rest,values)=
             let val coordinates=List.rev(K.N.literal n::values)
             in if List.length coordinates=3 then(K.vec coordinates,rest)
                else raise Fail "hidden selected scenes require three coordinates"end
          |components _=raise Fail "invalid hidden vector"
    in case tokens of Vec::Left::rest=>components(rest,[])|_=>raise Fail "missing hidden vector"end
  fun face text=
    let fun points(tokens,values)=
          let val(value,rest)=point tokens
          in case rest of Comma::tail=>points(tail,value::values)
            |[Right]=>S.fromList(List.rev(value::values))
            |_=>raise Fail "invalid hidden polygon"end
    in case tokenize text of Left::rest=>points(rest,[])|_=>raise Fail "missing hidden polygon"end
  fun scene text=
    let val rows=if text=""then[]else
          let val rows=String.fields(fn c=>c= #"\n")text
          in if String.sub(text,String.size text-1)= #"\n"then List.rev(tl(List.rev rows))else rows end
    in S.map face(S.fromList rows)end
  fun view text=case point(tokenize("vec["^text^"]"))of
      (value,[])=>value|_=>raise Fail "invalid hidden view"
end
