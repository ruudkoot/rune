structure BenchScsParse =
struct
  structure Q=BenchScsRational
  structure L=BenchLazy
  structure S=BenchStream
  structure P=BenchInferParsingFn(BenchNeed)
  structure T=BenchScsTypes
  fun return value=P.returnP(L.delay(fn()=>value))
  fun either first second=P.elseP first second
  fun allow fallback parser input=L.delay(fn()=>
    let val result=parser input
    in case P.expose result of P.Nil=>P.expose(P.returnP fallback input)|node=>node end)
  fun span predicate input=L.delay(fn()=>case L.force input of []=>P.Nil
    |first::rest=>if not(predicate first)then P.Nil else
      let fun loop [] prefix=(List.rev prefix,[])
            |loop(xs as x::rest)prefix=if predicate x then loop rest(x::prefix)else(List.rev prefix,xs)
          val(prefix,suffix)=loop rest[first]
      in P.expose(P.returnP(L.delay(fn()=>String.implode prefix))(L.delay(fn()=>suffix)))end)
  fun whitespace input=allow(L.delay(fn()=>""))(span Char.isSpace)input
  fun removeLeft first second=P.thenP first(fn _=>second)
  fun removeRight first second=P.thenP first(fn value=>P.thenP second(fn _=>P.returnP value))
  fun character c=removeLeft whitespace(P.litP c)
  fun parseWhile predicate=removeLeft whitespace(span predicate)
  fun option parser=either(P.thenP parser(fn value=>P.returnP(L.delay(fn()=>P.Cons(value,P.empty())))))
    (P.returnP(L.delay(fn()=>P.Nil)))
  fun sequence2 first second=P.thenP first(fn x=>P.thenP second(fn y=>P.returnP(L.delay(fn()=>(x,y)))))
  fun sequence3 first second third=P.thenP first(fn x=>P.thenP second(fn y=>P.thenP third(fn z=>
    P.returnP(L.delay(fn()=>(x,y,z))))))
  fun repetition0 parser input=allow(L.delay(fn()=>P.Nil))(P.consP parser(repetition0 parser))input
  fun repetition1 parser=P.consP parser(repetition0 parser)
  fun complete parser text=
    P.bind(removeRight parser whitespace(L.delay(fn()=>String.explode text)))(fn(value,rest)=>
      if List.null(L.force rest)then P.single value else P.empty())
  fun one kind results=case P.expose results of P.Nil=>raise Fail("cannot parse "^kind)
    |P.Cons(value,rest)=>(case P.expose rest of P.Nil=>L.force value|_=>raise Fail("ambiguous "^kind))
  fun large text=case IntInf.fromString text of SOME n=>n|NONE=>raise Fail "invalid decimal digits"
  fun scale c=case c of
      #"a"=>Q.make(1,1000000000000000000)| #"f"=>Q.make(1,1000000000000000)
    | #"p"=>Q.make(1,1000000000000)| #"n"=>Q.make(1,1000000000)
    | #"u"=>Q.make(1,1000000)| #"m"=>Q.make(1,1000)| #"k"=>Q.make(1000,1)
    | #"M"=>Q.make(1000000,1)| #"G"=>Q.make(1000000000,1)| #"T"=>Q.make(1000000000000,1)
    | #"P"=>Q.make(1000000000000000,1)| #"E"=>Q.make(1000000000000000000,1)
    | _=>raise Fail "invalid SI factor"
  fun exact input=
    let val sign=P.eachP(option(character #"-"))(fn P.Nil=>Q.one|_=>Q.negative Q.one)
        val integral=P.eachP(parseWhile Char.isDigit)(fn word=>Q.make(large word,1))
        val fractional=P.eachP(option(removeLeft(P.litP #".")(parseWhile Char.isDigit)))
          (fn P.Nil=>Q.zero|P.Cons(word,_)=>
            let val digits=L.force word in Q.make(large digits,IntInf.pow(10,String.size digits))end)
        val factor=P.eachP(option(P.filterP(fn c=>String.isSubstring(String.str c)"afpnumkMGTPE")P.itemP))
          (fn P.Nil=>Q.one|P.Cons(value,_)=>scale(L.force value))
    in P.thenP sign(fn sign=>P.thenP integral(fn integral=>P.thenP fractional(fn fractional=>P.thenP factor(fn factor=>
      P.returnP(L.delay(fn()=>Q.mul(Q.mul(L.force sign,Q.add(L.force integral,L.force fractional)),L.force factor)))))))input end
  fun approximate input=P.eachP exact Q.real input
  fun integer input=either(P.thenP(character #"-")(fn _=>P.eachP(parseWhile Char.isDigit)(fn digits=>IntInf.~(large digits))))
      (P.eachP(parseWhile Char.isDigit)large)input
  fun name input=parseWhile Char.isAlphaNum input
  fun waveform input=repetition1(removeLeft(character #"(")
      (removeRight(P.thenP approximate(fn first=>removeLeft(character #",")
        (P.thenP approximate(fn second=>P.returnP(L.delay(fn()=>(first,second)))))))(character #")")))input
  fun wave values=L.delay(fn()=>case P.expose values of P.Nil=>S.Nil|P.Cons(pair,rest)=>S.Cons(pair,wave rest))
  fun code c parameter=P.thenP(character c)(fn _=>P.thenP(sequence3 name name name)(fn names=>
      P.thenP parameter(fn value=>P.returnP(L.delay(fn()=>(value,names))))))
  fun element input=
    let val conductor=code #"g"(P.thenP exact(fn value=>return(T.Conductor value)))
        val resistor=code #"r"(P.thenP exact(fn value=>return(T.Resistor value)))
        val capacitor=code #"c"(P.thenP exact(fn c=>P.thenP exact(fn q=>return(T.Capacitor(c,q)))))
        val inductor=code #"l"(P.thenP exact(fn l=>P.thenP exact(fn flux=>return(T.Inductor(l,flux)))))
        val voltage=code #"v"(P.thenP waveform(fn values=>return(T.Vsource(wave values))))
        val current=code #"i"(P.thenP waveform(fn values=>return(T.Isource(wave values))))
        val junction=code #"j"(P.thenP exact(fn c=>P.thenP exact(fn r=>P.thenP exact(fn q=>return(T.Junction(c,r,q))))))
    in either conductor(either resistor(either capacitor(either inductor(either voltage(either current junction)))))input end
  fun makeIndices entries=
    let val entries=P.toList entries
        val typed=List.map(fn(value,names)=>
          let val(n1,n2,n3)=L.force names
          in(value,("i:"^L.force n1,"v:"^L.force n2,"v:"^L.force n3))end)entries
        fun nub seen []=[]|nub seen(x::xs)=if List.exists(fn y=>x=y)seen then nub seen xs else x::nub(x::seen)xs
        val names=nub[]("v:ground"::List.concat(List.map(fn(_, (a,b,c))=>[a,b,c])typed))
        fun index name=
          let fun loop [] _=raise Fail "missing circuit name"|loop(x::xs)n=if x=name then n else loop xs(n+1)
          in loop names 0 end
        val circuit=List.map(fn(value,(a,b,c))=>(index a,index b,index c,L.force value))typed
    in(circuit,names)end
  fun circuit input=P.thenP(repetition1 element)(fn entries=>P.returnP(L.delay(fn()=>makeIndices entries)))input
  fun readCircuit text=one "circuit"(complete circuit text)
  fun readExact text=one "exact value"(complete exact text)
  fun readApproximate text=one "approximate value"(complete approximate text)
  fun readInteger text=one "integer"(complete integer text)
end
