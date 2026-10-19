functor BenchTreeJoinFn (D : BENCH_SUSPEND) =
struct
  type number = int D.t
  datatype 'a node = Empty | Node of number * 'a node D.t * 'a node D.t | Leaf of number * 'a
  type 'a tree = 'a node D.t
  type entity = number * number * number
  type joined = number * number * number * number * number
  fun empty () = D.delay (fn () => Empty)
  fun insert key entry tree = D.delay (fn () =>
    case D.force tree of
      Empty => Leaf(key,entry)
    | Node(bound,left,right) =>
        if D.force key <= D.force bound then Node(bound,insert key entry left,right)
        else Node(bound,left,insert key entry right)
    | Leaf(old,_) =>
        if D.force key < D.force old then Node(key,D.delay(fn()=>Leaf(key,entry)),tree)
        else if D.force key > D.force old then Node(old,tree,D.delay(fn()=>Leaf(key,entry)))
        else raise Fail "duplicate relation key")
  fun lookup key tree =
    case D.force tree of Empty => NONE
    | Node(bound,left,right) => lookup key (if key<=D.force bound then left else right)
    | Leaf(old,entry) => if key=D.force old then SOME entry else NONE
  fun readTree text =
    let val size=String.size text
        fun skip i=if i<size andalso Char.isSpace(String.sub(text,i))then skip(i+1)else i
        fun integer start=
          let fun scan(i,total)=if i<size andalso Char.isDigit(String.sub(text,i))then
                let val digit=Char.ord(String.sub(text,i))-Char.ord #"0"
                in scan(i+1,D.delay(fn()=>D.force total*10+digit))end
                else(total,skip i)
          in scan(start,D.delay(fn()=>0))end
        fun records(pos,tree,count)=if pos=size then(tree,count)else
          let val(a,p1)=integer pos val(b,p2)=integer p1 val(c,p3)=integer p2
              val _=if p3>pos then()else raise Fail "invalid relation input"
          in records(p3,insert a(a,b,c)tree,count+1)end
    in records(0,empty(),0)end
  fun join left right output = D.delay(fn()=>
    case D.force left of Empty=>D.force output
    | leftNode => case D.force right of Empty=>D.force output
      | _ => case leftNode of
          Leaf(_, (a,b,c)) =>
            (case lookup(D.force c)right of NONE=>D.force output
             |SOME(d,e,_)=>D.force(insert c(a,b,c,d,e)output))
        |Node(_,l,r)=>D.force(join l right(join r right output))
        |Empty=>D.force output)
  fun lines tree =
    let fun visit(tree,acc)=case D.force tree of Empty=>acc
          |Node(_,l,r)=>visit(l,visit(r,acc))
          |Leaf(key,(a,b,c,d,e))=>
            let val values=List.map D.force[a,b,c,d,e]
                val _=if D.force key=List.nth(values,2)then()else raise Fail "join key differs"
                val line=String.concatWith" "(List.map Int.toString values)^"\n"
            in line::acc end
    in visit(tree,[])end
  fun file path=let val stream=TextIO.openIn path val text=TextIO.inputAll stream val _=TextIO.closeIn stream in text end
  fun run [first,second,reference] =
    let val _=if List.exists(fn trio=>trio=(first,second,reference))
          [("DATA/smoke.1","DATA/smoke.2","expected/smoke.txt"),
           ("DATA/normal.1","DATA/normal.2","expected/normal.txt"),
           ("DATA/large.1","DATA/large.2","expected/large.txt")]
          then()else raise Fail "treejoin input paths"
        val(a,na)=readTree(file first)val(b,nb)=readTree(file second)
        val output=lines(join a b(empty()))
        val actual=String.concat output
        val _=if actual=file reference then()else raise Fail "complete relation join differs"
    in Int.toString na^" "^Int.toString nb^" "^Int.toString(List.length output)end
    |run _=raise Fail "treejoin expects two relation files and reference"
end
