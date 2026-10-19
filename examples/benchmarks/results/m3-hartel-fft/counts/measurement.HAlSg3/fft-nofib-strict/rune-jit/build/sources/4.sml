functor BenchHartelFftFn (D : BENCH_SUSPEND) =
struct
  (* GHC 9.4.7 Data.Complex has strict real/imaginary fields. *)
  type complex = real * real
  datatype 'a node = Nil | Cons of 'a D.t * 'a node D.t
  type 'a seq = 'a node D.t
  fun empty () = D.delay(fn()=>Nil)
  fun fromList [] = empty ()
    | fromList(x::xs) = D.delay(fn()=>Cons(D.delay(fn()=>x),fromList xs))
  fun lengthFrom(count,xs) = case D.force xs of Nil=>count
    |Cons(_,rest)=>lengthFrom(count+1,rest)
  fun length xs=lengthFrom(0,xs)
  fun append xs ys = D.delay(fn()=>case D.force xs of Nil=>D.force ys
    |Cons(x,rest)=>Cons(x,append rest ys))
  fun concat values=D.delay(fn()=>case D.force values of Nil=>Nil
    |Cons(value,rest)=>D.force(append value(concat rest)))
  fun take 0 xs=empty()
    |take n xs=D.delay(fn()=>case D.force xs of Nil=>Nil|Cons(x,rest)=>Cons(x,take(n-1)rest))
  fun drop 0 xs=xs
    |drop n xs=D.delay(fn()=>case D.force xs of Nil=>Nil|Cons(_,rest)=>D.force(drop(n-1)rest))
  fun map f xs=D.delay(fn()=>case D.force xs of Nil=>Nil|Cons(x,rest)=>Cons(f x,map f rest))
  fun map2 f xs ys=D.delay(fn()=>case (D.force xs,D.force ys)of
      (Cons(x,xs),Cons(y,ys))=>Cons(f(x,y),map2 f xs ys)|_=>Nil)
  fun add((a,b):complex,(c,d):complex)=(a+c,b+d)
  fun subtract((a,b):complex,(c,d):complex)=(a-c,b-d)
  fun multiply((a,b):complex,(c,d):complex)=(a*c-b*d,a*d+b*c)
  val pi=D.delay(fn()=>4.0*Math.atan 1.0)
  fun unitRoot size n =
    let val angle=(Real.fromInt(2*n)/Real.fromInt size)*D.force pi
    in (Math.cos angle,Math.sin angle)end
  fun pow2 n=Word32.toInt(Word32.<<(0w1,Word.fromInt n))
  fun log2 n=Real.floor(Real.fromInt(Real.floor(Math.ln(Real.fromInt n)/Math.ln 2.0+0.5)))
  fun reverseBits width value=
    let fun loop(0,x,acc)=acc
          |loop(w,x,acc)=loop(w-1,x div 2,2*acc+x mod 2)
    in loop(width,value,0)end
  fun input coarse=
    let fun build i=D.delay(fn()=>if i=64 then Nil
          else Cons(D.delay(fn()=>(Real.fromInt(63-i),0.0)),build(i+1)))
        val base=build 0
        fun extend 0 xs=xs|extend n xs=extend(n-1)(append xs xs)
    in extend coarse base end
  fun arrayOfList xs=
    let val n=length xs
        val result=Array.array(n,D.delay(fn()=>(0.0,0.0)))
        fun fill(i,xs)=case D.force xs of Nil=>()|Cons(x,rest)=>(Array.update(result,i,x);fill(i+1,rest))
        val _=fill(0,xs)
    in result end
  fun elements values=
    let val n=Array.length values
        fun loop i=D.delay(fn()=>if i=n then Nil else Cons(Array.sub(values,i),loop(i+1)))
    in loop 0 end
  fun reorderArray values=
    let val n=Array.length values val width=D.delay(fn()=>log2 n)
        val index=Array.tabulate(n,fn i=>D.delay(fn()=>reverseBits(D.force width)i))
    in Array.tabulate(n,fn i=>D.delay(fn()=>D.force(Array.sub(values,D.force(Array.sub(index,i))))))end
  fun arrayFft size 0 values=values
    |arrayFft size n values=
      let val bit=log2(size div(n*2))
          val next=Array.array(size,D.delay(fn()=>(0.0,0.0)))
          val seen=Array.array(size,false)val writes=ref 0
          fun store(i,value)=if i>=0 andalso i<size andalso not(Array.sub(seen,i))
            then(Array.update(seen,i,true);writes:= !writes+1;Array.update(next,i,value))
            else raise Fail "incorrect result: duplicate or invalid FFT index"
          fun pair j=D.delay(fn()=>
            let val k=j+pow2 bit
                val x=D.delay(fn()=>D.force(Array.sub(values,j)))
                val y=D.delay(fn()=>D.force(Array.sub(values,k)))
                val z=D.delay(fn()=>multiply(unitRoot size(n*j),D.force y))
                val plus=D.delay(fn()=>add(D.force x,D.force z))
                val minus=D.delay(fn()=>subtract(D.force x,D.force z))
            in Cons(D.delay(fn()=>(j,plus)),
                 D.delay(fn()=>Cons(D.delay(fn()=>(k,minus)),empty())))end)
          fun chunks j=D.delay(fn()=>if j=size then Nil
            else if Word32.andb(Word32.fromInt j,Word32.<<(0w1,Word.fromInt bit))=0w0
              then Cons(pair j,chunks(j+1))else D.force(chunks(j+1)))
          fun fill entries=case D.force entries of Nil=>()
            |Cons(entry,rest)=>(store(D.force entry);fill rest)
          val _=fill(concat(chunks 0))
          val _=if !writes=size then()else raise Fail "incorrect result: incomplete FFT array"
      in arrayFft size(n div 2)next end
  fun arrayMain xs=
    let val size=length xs val reordered=reorderArray(arrayOfList xs)
    in elements(arrayFft size(size div 2)reordered)end
  fun listFft size n xs=D.delay(fn()=>case D.force xs of Nil=>raise Empty
    |Cons(x,rest)=>(case D.force rest of Nil=>Cons(x,empty())
      |_=>
        let val half=length xs div 2 val left=take half xs val right=drop half xs
            val root=D.delay(fn()=>unitRoot size n)
            val products=map(fn value=>D.delay(fn()=>multiply(D.force root,D.force value)))right
            val plus=map2(fn(a,b)=>D.delay(fn()=>add(D.force a,D.force b)))left products
            val minus=map2(fn(a,b)=>D.delay(fn()=>subtract(D.force a,D.force b)))left products
        in D.force(append(listFft size(n div 2)plus)(listFft size(n div 2+size div 4)minus))end))
  fun join n xs ys=D.delay(fn()=>case(D.force xs,D.force ys)of(Nil,Nil)=>Nil
    |_=>D.force(append(take n xs)(append(take n ys)(join n(drop n xs)(drop n ys)))))
  fun reorder 1 xs=xs
    |reorder n xs=D.delay(fn()=>
      let val size=length xs val half=size div 2
      in D.force(reorder(n div 2)(join(size div n)(take half xs)(drop half xs)))end)
  fun listMain xs=let val size=length xs in reorder size(listFft size 0 xs)end
  fun reference coarse=
    let val copies=pow2 coarse val n=64*copies
    in Vector.tabulate(n,fn k=>if k mod copies<>0 then(0.0,0.0)
         else if k=0 then(Real.fromInt(2016*copies),0.0)
         else let val half=Real.fromInt n/2.0 val q=k div copies
              in (half,half/Math.tan(Math.pi*Real.fromInt q/64.0))end)end
  fun componentClose(observed,expected)=Real.isFinite observed andalso Real.isFinite expected
    andalso Real.abs(observed-expected)<=1.0E~7+1.0E~12*Real.abs expected
  fun checkValue((a,b),(c,d))=if componentClose(a,c)andalso componentClose(b,d)then()
    else raise Fail "incorrect result: FFT differs from analytic spectrum"
  fun sourceCompare((a,b):complex,(c,d):complex)=Real.abs(a-c)<=0.5 andalso Real.abs(b-d)<=0.5
  val truth=fromList [#"t"]
  fun comparisons expected i xs ys=D.delay(fn()=>case(D.force xs,D.force ys)of
      (Nil,Nil)=>Nil
    |(Cons(x,xs),Cons(y,ys))=>
       Cons(D.delay(fn()=>
         let val a=D.force x val b=D.force y val wanted=Vector.sub(expected,i)
             val _=checkValue(a,wanted)val _=checkValue(b,wanted)
             val _=if sourceCompare(a,b)then()else raise Fail "incorrect result: FFT algorithms disagree"
         in D.force truth end),comparisons expected(i+1)xs ys)
    |_=>raise Fail "incorrect result: FFT result dimensions differ")
  fun digest(xs,total,count)=case D.force xs of Nil=>(total+count,count)
    |Cons(value,rest)=>digest(rest,total+Char.ord(D.force value),count+1)
  fun run coarse expected=
    let val source=input coarse
        val result=digest(concat(comparisons expected 0(arrayMain source)(listMain source)),0,0)
        val size=64*pow2 coarse
        val _=if result=(117*size,size)then()else raise Fail "incorrect result: FFT status checksum differs"
    in Int.toString(#1 result)^"/"^Int.toString(#2 result)end
end
