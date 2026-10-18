  fun reduction1 v1=D.delay(fn()=>S4(get4 v1))
  fun reduction2 v3 _ v1=D.delay(fn()=>
    let val rest=get4 v3 val first=get6 v1 in S4(F.cons(first,rest))end)
  fun reduction3 v1=D.delay(fn()=>S4(singleton(get6 v1)))
  val reduction4:semantic=D.delay(fn()=>S4(F.empty()))
  fun reduction5 v3 _ v1=D.delay(fn()=>
    let val tokens=get7 v3 val attr=selfName(terminal v1)
    in S6(D.delay(fn()=>SelfAssign(attr,tokens)))end)
  fun reduction6 v3 _ v1=D.delay(fn()=>
    let val tokens=get7 v3 val attr=subName(terminal v1)
    in S6(D.delay(fn()=>SubAssign(attr,tokens)))end)
  fun reduction7 v3 _ v1=D.delay(fn()=>
    let val tokens=get7 v3 val attr=rightName(terminal v1)
    in S6(D.delay(fn()=>RightmostAssign(attr,tokens)))end)
  fun reduction8 v2 _=D.delay(fn()=>let val tokens=get7 v2 in S6(D.delay(fn()=>Conditional tokens))end)
  fun reduction9 stack=L.delay(fn()=>
    let val(v4,s)=pop stack val tail=get7 v4
        val(v3,s)=pop s val close=terminal v3
        val(v2,s)=pop s val body=get7 v2
        val(v1,s)=pop s val openToken=terminal v1
    in Stk(D.delay(fn()=>S7(F.append(singleton(D.delay(fn()=>openToken)))
       (F.append body(F.cons(D.delay(fn()=>close),tail))))),s)end)
  fun reduction10 v2 v1=D.delay(fn()=>
    let val tail=get7 v2 val first=terminal v1 in S7(F.cons(D.delay(fn()=>first),tail))end)
  val reduction11=reduction10
  val reduction12=reduction10
  val reduction13=reduction10
  val reduction14=reduction10
  val reduction15:semantic=D.delay(fn()=>S7(F.empty()))
  val reduction16=reduction9
  val reduction17=reduction10
  val reduction18=reduction10
  val reduction19=reduction10
  val reduction20=reduction10
  val reduction21=reduction10
  val reduction22=reduction10
  val reduction23:semantic=D.delay(fn()=>S7(F.empty()))
