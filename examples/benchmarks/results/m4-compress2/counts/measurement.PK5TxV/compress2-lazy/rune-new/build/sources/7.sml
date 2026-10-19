(* Port of pinned nofib real/compress2; retain original sources and
   program/dataset notice status in each workload PROVENANCE.md. *)
(* Variable-width prefix-trie compressor. Feedback/event streams are memoized
   in both variants; D controls eager versus memoized dictionary construction. *)
functor BenchCompress2Fn(D : BENCH_SUSPEND) =
struct
  structure B=BenchCompress2Bits
  structure N=BenchNeed
  structure S=B.S
  datatype trieNode=PTNil | PT of char D.t*int D.t*trieNode D.t*trieNode D.t*trieNode D.t
  type trie=trieNode D.t
  type match=int*int N.t*int
  type update=(match N.t*trie)N.t
  fun value x=D.delay(fn()=>x)
  fun empty()=D.delay(fn()=>PTNil)
  fun build lo hi=D.delay(fn()=>if lo>hi then PTNil else
    let val mid=(lo+hi)div 2
    in PT(value(Char.chr mid),value mid,empty(),build lo(mid-1),build(mid+1)hi)end)
  val initial=build 0 255
  val firstEntry=257
  val firstChange=513
  val maxCode=65537
  fun dataOf(result:update)=N.delay(fn()=>N.force(#1(N.force result)))
  fun treeOf(result:update)=D.delay(fn()=>D.force(#2(N.force result)))
  fun searchRead input position old matched table=N.delay(fn()=>
    if position=String.size input then(position,old,matched)
    else case D.force table of PTNil=>(position,old,matched)
      | PT(key,code,prefix,left,right)=>
          case Char.compare(String.sub(input,position),D.force key)of
            EQUAL=>N.force(searchRead input(position+1)(N.delay(fn()=>D.force code))(matched+1)prefix)
          | LESS=>N.force(searchRead input position old matched left)
          | GREATER=>N.force(searchRead input position old matched right))
  fun searchWrite input position old matched next table:update=N.delay(fn()=>
    if position=String.size input then(N.delay(fn()=>(position,old,matched)),empty())
    else case D.force table of
      PTNil=>(N.delay(fn()=>(position,old,matched)),
        D.delay(fn()=>PT(value(String.sub(input,position)),value next,empty(),empty(),empty())))
    | PT(key,code,prefix,left,right)=>
        case Char.compare(String.sub(input,position),D.force key)of
          LESS=>let val child=searchWrite input position old matched next left
                in(dataOf child,D.delay(fn()=>PT(key,code,prefix,treeOf child,right)))end
        | GREATER=>let val child=searchWrite input position old matched next right
                   in(dataOf child,D.delay(fn()=>PT(key,code,prefix,left,treeOf child)))end
        | EQUAL=>let val child=searchWrite input(position+1)(N.delay(fn()=>D.force code))(matched+1)next prefix
                 in(dataOf child,D.delay(fn()=>PT(key,code,treeOf child,left,right)))end)
  fun encode(bo,ci,checkpoint,ratio,next,change)table sizes input position=N.delay(fn()=>
    if position=String.size input then S.Nil
    else if next=change then
      let val candidate=(change-1)*2+1
          val nextChange=if candidate=maxCode then 0 else candidate
          val tail=N.delay(fn()=>N.force(encode(bo+S.head sizes,ci,checkpoint,ratio,next,nextChange)table(S.tail sizes)input position))
      in S.Cons(N.delay(fn()=>B.NewWordSize),tail)end
    else if next=maxCode andalso ci>=checkpoint then
      let val newRatio=(ci*256)div bo
      in if newRatio>ratio then
           N.force(encode(bo,ci,ci+10000,newRatio,next,change)table sizes input position)
         else
           let val tail=N.delay(fn()=>N.force(encode(bo+S.head sizes,ci,ci+10000,0,firstEntry,firstChange)initial(S.tail sizes)input position))
           in S.Cons(N.delay(fn()=>B.Clear),tail)end
      end
    else
      let
        val changed=if next=maxCode then NONE else SOME(searchWrite input position(N.delay(fn()=>0))0 next table)
        val matched=case changed of NONE=>searchRead input position(N.delay(fn()=>0))0 table | SOME result=>dataOf result
        val code=N.delay(fn()=>let val(_,value,_)=N.force matched in N.force value end)
        val tail=N.delay(fn()=>
          let val amount=S.head sizes
              val(index,_,count)=N.force matched
              val dictionary=case changed of NONE=>table | SOME result=>treeOf result
              val entry=case changed of NONE=>next | SOME _=>next+1
          in N.force(encode(bo+amount,ci+count,checkpoint,ratio,entry,change)dictionary(S.tail sizes)input index)end)
      in S.Cons(N.delay(fn()=>B.Code code),tail)end)
  fun compress input=
    let val knot=ref(NONE:B.result option)
        val feedback=N.delay(fn()=>
          case !knot of NONE=>raise Fail "compression feedback used before initialization"
          | SOME result=>(knot:=NONE;N.force(B.sizes result)))
        val codes=encode(3,1,10000,0,firstEntry,firstChange)initial feedback input 0
        val output=B.outputCodes codes
        val _=knot:=SOME output
        val bytes=String.implode(S.toList(B.characters output))
    in String.implode[Char.chr 31,Char.chr 157,Char.chr 144]^bytes end
end
