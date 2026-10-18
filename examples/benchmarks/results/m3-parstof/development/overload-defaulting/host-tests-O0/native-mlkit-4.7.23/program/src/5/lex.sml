(* Finite lexical attributes use D; character/token control remains memoized. *)
functor BenchParstofLexFn(D:BENCH_SUSPEND)=
struct
 structure L=BenchLazy
 datatype chars=End|Ch of char*chars L.delay
 type input=chars L.delay
 datatype tokenValue=Empty|Character of char D.t|Integer of int D.t
   |Text of char list D.t|Error of char*string
 type token=int*tokenValue*int
 datatype tokens=Done|Tok of token*tokens L.delay
 datatype 'a result=No|Yes of 'a D.t*input
 type 'a pattern=char list*(input->'a result)
 fun chars text=
   let fun loop i=L.delay(fn()=>if i=String.size text then End
         else Ch(String.sub(text,i),loop(i+1)))
   in loop 0 end
 fun sequence join first last stream=case first stream of No=>No
   |Yes(a,rest)=>(case last rest of No=>No
      |Yes(b,tail)=>Yes(D.delay(fn()=>join a b),tail))
 fun seq join(starts,first)(_,last)=(starts,sequence join first last)
 fun convertCell cvt(starts,parser)=
   (starts,fn input=>case parser input of No=>No|Yes(a,rest)=>Yes(D.delay(fn()=>cvt a),rest))
 fun convert cvt pattern=convertCell(fn value=>cvt(D.force value))pattern
 fun literal c=([c],fn stream=>case L.force stream of
     Ch(x,rest)=>if c=x then Yes(D.delay(fn()=>c),rest)else No|End=>No)
 fun split count xs=if count=0 then([],xs)
   else case xs of x::rest=>let val(a,b)=split(count-1)rest in(x::a,b)end
     |[]=>raise Fail"parstof lexical split"
 fun merge [] ys=ys|merge xs []=xs
   |merge(xs as x::rest)(ys as y::tail)=if x<=y then x::merge rest ys else y::merge xs tail
 fun sort []=[]|sort[x]=[x]
   |sort xs=let val(a,b)=split(List.length xs div 2)xs in merge(sort a)(sort b)end
 fun unique []=[]|unique(x::xs)=
   let fun loop _ []=[]|loop previous(y::ys)=if previous=y then loop previous ys else y::loop y ys
   in x::loop x xs end
 fun alt(patterns:'a pattern list):'a pattern=
   let val starts=unique(sort(List.concat(List.map #1 patterns)))
       val choices=List.map(fn c=>(c,List.map #2(List.filter(fn(cs,_)=>List.exists(fn x=>x=c)cs)patterns)))starts
       fun try [] _=No|try(f::fs)stream=case f stream of No=>try fs stream|answer=>answer
       fun tree []=(fn _=>No)
         |tree[(c,functions)]=(fn stream=>case L.force stream of
             Ch(x,_)=>if c=x then try functions stream else No|End=>No)
         |tree choices=
            let val(left,right)=split(List.length choices div 2)choices
                val pivot= #1(List.last left)
                val first=tree left val last=tree right
            in fn stream=>case L.force stream of Ch(c,_)=>if pivot<c then last stream else first stream|End=>No end
   in(starts,tree choices)end
 fun repeat join initial parser stream=case parser stream of No=>Yes(initial,stream)
   |Yes(value,rest)=>repeat join(D.delay(fn()=>join(D.force initial)(D.force value)))parser rest
 fun plus join initial(starts,parser)=
   (starts,fn stream=>case parser stream of No=>No
      |Yes(value,rest)=>repeat join(D.delay(fn()=>join initial(D.force value)))parser rest)
 fun select1 a _=D.force a
 fun select2 _ b=D.force b
 fun cons a b=D.force a::D.force b
 fun singleton a=[a]
 fun addChar text c=text@[c]
 fun match text=
   let fun consume [] stream=Yes(D.delay(fn()=>[]:char list),stream)
         |consume(c::cs)stream=sequence select2(#2(literal c))(consume cs)stream
       val cs=String.explode text
   in(case cs of c::_=>[c]|[]=>raise Fail"empty lexical literal",consume cs)end
 val digits=alt(List.map literal(String.explode"0123456789"))
 val upper=alt(List.map literal(String.explode"ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
 val lower=alt(List.map literal(String.explode"abcdefghijklmnopqrstuvwyxz"))
 val alphanum=alt[digits,upper,lower]
 fun escape _ value=case D.force value of #"n"=> #"\n"| #"t"=> #"\t"| #"f"=> #"\012"
   | #"\\"=> #"\\"| #"'"=> #"'"| #"\""=> #"\""|_=> #"@"
 val escapedChar=alt(List.map literal(String.explode"ntf\\'\""))
 val hexDigit=alt(digits::List.map literal(String.explode"ABCDEF"))
 (* Preserve the source's character-code subtraction, including its A..F quirk. *)
 fun hex first last=Char.chr(16*(Char.ord(D.force first)-Char.ord #"0")+(Char.ord(D.force last)-Char.ord #"0"))
 val escaped=alt[seq escape(literal #"\\")escapedChar,seq select2(literal #"\\")(seq hex hexDigit hexDigit)]
 val weird=alt(List.map literal(String.explode"!#$%&()*+,-./:;<=>?@[]^"@[Char.chr 96]@String.explode"{|}~ \t"))
 val chchar=alt[alphanum,escaped,weird,literal #"\""]
 val character=seq select2(literal #"'")(seq select1 chchar(literal #"'"))
 val integer=plus(fn n=>fn digit=>10*n+Char.ord digit-Char.ord #"0")0 digits
 val uppid=alt[seq cons upper(plus addChar[]alphanum),convert singleton upper]
 val lowid=alt[seq cons lower(plus addChar[]alphanum),convert singleton lower]
 val strchar=alt[alphanum,escaped,weird,literal #"'"]
 val endstr=alt[convert(fn _=>[])(literal #"\""),seq select1(plus addChar[]strchar)(literal #"\"")]
 val string=seq select2(literal #"\"")endstr
 fun empty tag parser=convertCell(fn _=>(tag,Empty))parser
 fun valChar c=(11,Character c)
 fun valInt n=(12,Integer n)
 fun valText tag text=(tag,Text text)
 val punctuation=[(26,"->"),(31,"++"),(32,":"),(33,"&"),(34,"|"),
   (35,"<="),(37,"~="),(36,"=="),(38,">="),(39,"<"),(40,">"),(30,"="),
   (41,"+"),(42,"-"),(43,"*"),(44,"/"),(45,"%"),(46,"~"),(47,"["),
   (50,"]"),(51,"{"),(52,"}"),(53,"("),(54,")"),(55,";"),(56,","),(57,"#")]
 val keywords=[(15,"TYPE"),(16,"FTYPE"),(17,"LET"),(18,"IN"),(19,"IF"),
   (20,"THEN"),(21,"ELIF"),(22,"ELSE"),(23,"FI"),(24,"CASE")]
 val matcher=alt([convertCell valChar character,convertCell valInt integer]@
    List.map(fn(tag,text)=>empty tag(match text))keywords@
    [convertCell(valText 25)uppid,convertCell(valText 13)string,convertCell(valText 14)lowid]@
    List.map(fn(tag,text)=>empty tag(match text))punctuation)
 fun prefix text stream=
   let fun loop [] _=true
         |loop(c::cs)stream=case L.force stream of Ch(x,rest)=>c=x andalso loop cs rest|End=>false
   in loop(String.explode text)stream end
 fun scanComment stream line=case L.force stream of End=>NONE
   |Ch(c,rest)=>if c= #"\n"then scanComment rest(line+1)
      else if prefix"*/"stream then(case L.force rest of Ch(_,tail)=>SOME(tail,line)|End=>raise Fail"comment terminator")
      else scanComment rest line
 fun skip stream line=case L.force stream of End=>SOME(stream,line)
   |Ch(c,rest)=>if c= #" "orelse c= #"\t"orelse c= #"\012"then skip rest line
      else if c= #"\n"then skip rest(line+1)
      else if prefix"/*"stream then(case scanComment stream line of NONE=>NONE|SOME(next,n)=>skip next n)
      else SOME(stream,line)
 fun tokenizeAt stream line=L.delay(fn()=>case skip stream line of
     NONE=>(case L.force stream of Ch(c,_)=>Tok((60,Error(c,"Illegal comment"),line),L.delay(fn()=>Done))
          |End=>raise Fail"empty illegal comment")
    |SOME(next,n)=>(case L.force next of End=>Tok((61,Empty,n),L.delay(fn()=>Done))
       |Ch(c,rest)=>(case #2 matcher next of No=>Tok((60,Error(c,"Lexical error"),n),tokenizeAt rest n)
         |Yes(pair,tail)=>let val(tag,value)=D.force pair
                          in Tok((tag,value,n),tokenizeAt tail n)end)))
 fun tokenize text=tokenizeAt(chars text)1
end
