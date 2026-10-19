structure BenchRegex =
struct
  datatype piece = Literal of char | Alphabet of char*char | Numeric of int*int*int
  fun parse text =
    let fun decimal digits =
          if null digits orelse not(List.all Char.isDigit digits) then raise Fail "numeric expression range"
          else case Int.fromString(String.implode digits)of SOME n=>n|NONE=>raise Fail "numeric range overflow"
        fun until stop ([],_) = raise Fail "unterminated expression range"
          | until stop (c::cs,acc)=if c=stop then(List.rev acc,cs)else until stop(cs,c::acc)
        fun loop []=[]
          |loop (#"[" :: a :: #"-" :: b :: #"]" :: rest)=Alphabet(a,b)::loop rest
          |loop(#"<"::rest)=let val(left,rest1)=until #"-"(rest,[]) val(right,rest2)=until #">"(rest1,[])
               val u=decimal left val v=decimal right val width=Int.max(String.size(Int.toString u),String.size(Int.toString v))
             in Numeric(u,v,width)::loop rest2 end
          |loop(c::rest)=if Char.ord c<128 then Literal c::loop rest else raise Fail "non-ASCII expression"
    in loop(String.explode text)end
  fun values(Literal c)=[[c]]
    |values(Alphabet(a,b))=let val lo=Char.ord a val hi=Char.ord b val step=if lo<=hi then 1 else ~1
        fun range i=if(if step=1 then i>hi else i<hi)then[]else[Char.chr i]::range(i+step)
      in range lo end
    |values(Numeric(u,v,width))=let val step=if u<v then 1 else ~1
        fun range i=if(if step=1 then i>v else i<v)then[]else
          let val s=Int.toString i val pad=List.tabulate(width-String.size s,fn _=> #"0")
          in (pad@String.explode s)::range(i+step)end
      in range u end
  fun addChar(c,w)=Word64.+(Word64.fromInt(Char.ord c),Word64.*(w,0w31))
  fun run calculate [expression,reps,wantHash,wantLength] =
    let val count=BenchInput.between(1,500)(BenchInput.integer reps)
        val expected=case IntInf.fromString wantHash of SOME n=>n|NONE=>raise Fail "expression hash"
        val length=BenchInput.integer wantLength
        val pieces=parse expression
        fun one()=let val(hash,n)=calculate pieces
          in if Word64.toLargeIntX hash=expected andalso n=length then n else raise Fail "expression expansion differs"end
    in IntInf.toString(BenchInput.repeat count one)end
    |run _ _=raise Fail "gen_regexps expects expression repetitions hash character-count"
end
