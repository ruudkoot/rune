structure Benchmark =
struct
  val name="cse"
  datatype 'a tree=Node of 'a*'a tree list
  fun labelTree tree=
    let fun label(Node(value,children))=
          BenchState.bind(BenchState.update(fn n=>n+1))(fn index=>
            BenchState.bind(BenchState.mapList label children)(fn ts=>BenchState.return(Node((index,value),ts))))
    in BenchState.starting(label tree)0 end
  fun graph(Node((index,value),children))=
    let fun label(Node((n,_),_))=n
    in(index,value,List.map label children)::List.concat(List.map graph children)end
  fun findCommon nodes=
    let fun simplify((index,symbol,children),(rename,kept))=
          let val renamed=List.map rename children
              val matches=List.filter(fn(_,s,cs)=>s=symbol andalso cs=renamed)kept
          in case matches of []=>(rename,(index,symbol,renamed)::kept)
            |(representative,_,_)::_=>(fn key=>if key=index then representative else rename key,kept)end
    in #2(List.foldr simplify(fn key=>key,[])nodes)end
  fun cse tree=findCommon(graph(labelTree tree))
  fun leaf text=Node(text,[])
  fun plus x y=Node("+",[x,y])
  fun multiply x y=Node("*",[x,y])
  val a=leaf"a" val b=leaf"b" val c=leaf"c" val d=leaf"d" val zero=leaf"0"
  fun scanLeft [] _=[]|scanLeft(x::xs)acc=let val next=plus acc x in next::scanLeft xs next end
  fun scanRight []=[zero]|scanRight(x::xs)=let val rest=scanRight xs in plus x(List.hd rest)::rest end
  val examples=[a,plus a a,plus(multiply a b)(multiply a b),plus(multiply(plus a b)c)(plus a b),
    Node("X",zero::scanLeft[a,b,c,d]zero),Node("X",scanRight[a,b,c,d])]
  fun ints xs="["^String.concatWith","(List.map Int.toString xs)^"]"
  fun render nodes="["^String.concatWith","(List.map(fn(n,s,cs)=>"("^Int.toString n^",\""^s^"\","^ints cs^")")nodes)^"]"
  fun run[size,reference]=
    let val n=BenchInput.between(1,1500000)(BenchInput.integer size)
        val _=if reference="expected/graphs.txt"then()else raise Fail "CSE reference path"
        val stream=TextIO.openIn reference val expected=String.tokens(fn c=>c= #"\n")(TextIO.inputAll stream)val _=TextIO.closeIn stream
        val _=if List.length expected=6 then()else raise Fail "CSE example count"
        fun one trees index total=case trees of []=>total|tree::rest=>
          let val nodes=cse tree val _=if render nodes=List.nth(expected,index)then()else raise Fail "CSE complete graph differs"
          in one rest(index+1)(total+List.length nodes)end
        fun loop(i,total)=if i>n then total else
          loop(i+1,IntInf.+(total,IntInf.fromInt(one(List.take(examples,i mod 6))0 0)))
    in IntInf.toString(loop(1,0))end
    |run _=raise Fail "cse expects iteration-count reference"
end
