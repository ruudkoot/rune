functor BenchAtomFn (D : BENCH_SUSPEND) =
struct
  structure L=BenchLazy
  structure S=BenchStream
  structure Single=BenchMandelSingle
  datatype 'a node=Nil|Cons of 'a D.t * 'a node D.t
  type vector=real node D.t
  datatype atom=State of vector * vector
  fun empty()=D.delay(fn()=>Nil)
  fun fromList []=empty()|fromList(x::xs)=D.delay(fn()=>Cons(D.delay(fn()=>x),fromList xs))
  fun add xs ys=D.delay(fn()=>case D.force ys of Nil=>D.force xs
    |Cons(y,yr)=>(case D.force xs of Nil=>D.force ys
      |Cons(x,xr)=>Cons(D.delay(fn()=>Single.add(D.force x,D.force y)),add xr yr)))
  fun multiply xs ys=D.delay(fn()=>case D.force ys of Nil=>Nil
    |Cons(y,yr)=>(case D.force xs of Nil=>Nil
      |Cons(x,_)=>Cons(D.delay(fn()=>Single.mul(D.force x,D.force y)),multiply yr yr)))
  fun scale factor values=D.delay(fn()=>case D.force values of Nil=>Nil
    |Cons(value,rest)=>Cons(D.delay(fn()=>Single.mul(factor,D.force value)),scale factor rest))
  fun forceLaw param states=L.delay(fn()=>case L.force states of S.Nil=>S.Nil
    |S.Cons(value,rest)=>
       let val State(position,_)=L.force value
       in S.Cons(L.delay(fn()=>multiply(scale (~1.0)param)position),forceLaw param rest)end)
  fun propagate dt force state=
    let val State(position,velocity)=L.force state
    in State(D.delay(fn()=>D.force(add position(scale dt velocity))),
             D.delay(fn()=>D.force(add velocity(scale dt(L.force force)))))end
  fun steps dt forces states=case L.force forces of S.Nil=>S.Nil
    |S.Cons(force,fr)=>(case L.force states of S.Nil=>S.Nil
      |S.Cons(state,sr)=>S.Cons(L.delay(fn()=>propagate dt force state),L.delay(fn()=>steps dt fr sr)))
  fun experimentNode law dt param initial=
    let val child=L.delay(fn()=>experimentNode law dt param initial)
    in S.Cons(initial,L.delay(fn()=>steps dt(law param child)child))end
  fun experiment law dt param initial=L.delay(fn()=>experimentNode law dt param initial)
  val dt=Single.round 0.02
  fun start()=experiment forceLaw dt(fromList[1.0])
    (L.delay(fn()=>State(fromList[1.0],fromList[0.0])))
  fun bits value=
    let val sign:Word32.word=if Real.signBit value then 0wx80000000 else 0w0
    in if Real.==(value,0.0)then sign else
      let val _=if Real.isFinite value then()else raise Fail "incorrect result: nonfinite atom position"
          val{man,exp}=Real.toManExp(Real.abs value)
          val _=if exp>= ~125 andalso exp<=128 then()else raise Fail "incorrect result: atom leaves normal binary32 domain"
          val significand=Real.toInt IEEEReal.TO_ZERO(man*16777216.0)
          val _=if Real.==(Real.fromInt significand,man*16777216.0)then()
            else raise Fail "incorrect result: atom value is not binary32"
      in Word32.orb(sign,Word32.orb(Word32.<<(Word32.fromInt(exp+126),0w23),Word32.fromInt(significand-8388608)))end
    end
  fun format value=
    let val text=Real.fmt(StringCvt.GEN(SOME 9))value
        val _=CharVector.app(fn c=>if Char.isDigit c orelse List.exists(fn x=>x=c)[#"~",#"-",#"+",#".",#"e",#"E"]
          then()else raise Fail "incorrect result: atom formatter produced a nonnumeric character")text
        val _=if String.size text>0 andalso String.size text<=32 then()
          else raise Fail "incorrect result: atom formatter length differs"
        val parsed=case Real.fromString text of SOME x=>x|NONE=>raise Fail "incorrect result: atom formatter does not roundtrip"
        val _=if bits(Single.round parsed)=bits value then()
          else raise Fail "incorrect result: atom formatter loses binary32 value"
    in String.size(text^"\t\n")end
  fun run count expected=
    let fun loop(index,remaining,states,hash,written)=if remaining=0 then
          if index=Vector.length expected andalso written>=index*3 andalso written<=index*34 then Int.toString index^":"^Word32.toString hash
          else raise Fail "incorrect result: atom reference has extra positions"
        else case L.force states of S.Nil=>raise Fail "incorrect result: atom stream ended"
          |S.Cons(value,rest)=>
             let val State(position,_)=L.force value
                 val actual=case D.force position of Nil=>raise Fail "incorrect result: atom position is empty"
                   |Cons(x,xs)=>(case D.force xs of Nil=>D.force x|_=>raise Fail "incorrect result: atom dimension differs")
                 val observed=bits actual
                 val _=if index<Vector.length expected andalso observed=Vector.sub(expected,index)then()
                   else raise Fail "incorrect result: atom binary32 position differs"
                 val bytes=format actual
                 val next=Word32.*(Word32.xorb(hash,observed),0wx01000193)
             in loop(index+1,remaining-1,rest,next,written+bytes)end
    in loop(0,count,start(),0wx811C9DC5,0)end
end
