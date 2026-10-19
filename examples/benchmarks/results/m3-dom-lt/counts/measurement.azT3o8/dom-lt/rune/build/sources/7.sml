(* The benchmark data uses Haskell's tuple/list/decimal-integer Read syntax. *)
structure BenchDomReader =
struct
  datatype value=Integer of int|Tuple of value list|List of value list
  fun parse text=
    let val index=ref 0 val n=String.size text
        fun skip()=if !index<n andalso Char.isSpace(String.sub(text,!index))then(index:= !index+1;skip())else()
        fun peek()=(skip();if !index<n then SOME(String.sub(text,!index))else NONE)
        fun need c=(skip();if !index<n andalso String.sub(text,!index)=c then index:= !index+1
          else raise Fail "invalid graph data delimiter")
        fun values close constructor=
          let fun collect acc=case peek()of SOME c=>if c=close then(need close;constructor(rev acc))else
                    let val item=one()
                    in case peek()of SOME #","=>(need #",";collect(item::acc))
                      |SOME c=>if c=close then(need close;constructor(rev(item::acc)))
                        else raise Fail "invalid graph list"
                      |NONE=>raise Fail "unterminated graph list"end
                |NONE=>raise Fail "unterminated graph tuple"
          in collect[]end
        and one()=case peek()of SOME #"("=>(need #"(";values #")" Tuple)
          |SOME #"["=>(need #"[";values #"]" List)
          |SOME c=>if c= #"-"orelse Char.isDigit c then
            let val start= !index val negative=c= #"-"
                val _=if negative then index:= !index+1 else()
                val digits= !index
                fun scan()=if !index<n andalso Char.isDigit(String.sub(text,!index))then(index:= !index+1;scan())else()
                val _=scan()
                val _=if !index=digits then raise Fail "missing graph integer"else()
                val body=String.substring(text,digits,!index-digits)
                val spelling=(if negative then"~"else"")^body
            in case Int.fromString spelling of SOME value=>Integer value|NONE=>raise Fail "graph integer outside portable range"end
          else raise Fail "invalid graph data character"
          |NONE=>raise Fail "missing graph value"
        fun all acc=case peek()of NONE=>rev acc|_=>all(one()::acc)
    in all[]end
  fun integer(Integer n)=n|integer _=raise Fail "expected graph integer"
  fun entry(Tuple[Integer node,List successors])=(node,List.map integer successors)
    |entry _=raise Fail "expected graph adjacency entry"
  fun graph(Tuple[Integer root,List entries])=(root,BenchDomGraph.fromAdj(List.map entry entries))
    |graph _=raise Fail "expected rooted graph"
  fun pair(Tuple[Integer node,Integer parent])=(node,parent)
    |pair _=raise Fail "expected dominator pair"
  fun parents(List pairs)=List.map pair pairs|parents _=raise Fail "expected dominator pairs"
  fun graphs text=List.map graph(parse text)
  fun results text=List.map parents(parse text)
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
end
