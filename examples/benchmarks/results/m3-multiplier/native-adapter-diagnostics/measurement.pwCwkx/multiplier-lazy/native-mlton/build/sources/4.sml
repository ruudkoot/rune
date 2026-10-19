(* Binary multiplier: John T. O'Donnell, University of Glasgow.
   Copyright (c) 1992 John T. O'Donnell; July 1992 source retained upstream. *)
functor BenchMultiplierFn(P:sig val eagerBinary:bool end)=
struct
  structure L=BenchLazy
  structure S=BenchStream
  type bit=int S.stream
  type word=bit S.stream
  fun constant value=S.fix(fn self=>S.Cons(L.delay(fn()=>value),self))
  val zero=constant 0
  val one=constant 1
  fun latch input=S.cons(L.delay(fn()=>0),input)
  fun forceBit bit=bit=0
  fun headstrict force values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
    |S.Cons(x,rest)=>(force(L.force x);S.Cons(x,rest)))
  fun lift11 force f values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
    |S.Cons(x,rest)=>L.force(headstrict force(S.cons(L.delay(fn()=>f(L.force x)),lift11 force f rest))))
  fun lift21 force f left right=L.delay(fn()=>case(L.force left,L.force right)of
      (S.Cons(x,xs),S.Cons(y,ys))=>
        let val value=L.delay(fn()=>f(L.force x)(L.force y))
            val _=if P.eagerBinary then(force(L.force value);())else()
        in S.Cons(value,lift21 force f xs ys)end
    |_=>raise Match)
  fun lift31 force f xs ys zs=L.delay(fn()=>case L.force xs of S.Nil=>S.Nil
    |S.Cons(x,xr)=>case L.force ys of S.Nil=>S.Nil|S.Cons(y,yr)=>
      case L.force zs of S.Nil=>S.Nil|S.Cons(z,zr)=>
        L.force(headstrict force(S.cons(L.delay(fn()=>f(L.force x)(L.force y)(L.force z)),lift31 force f xr yr zr))))
  fun lift41 force f ws xs ys zs=L.delay(fn()=>case L.force ws of S.Nil=>S.Nil
    |S.Cons(w,wr)=>case L.force xs of S.Nil=>S.Nil|S.Cons(x,xr)=>case L.force ys of S.Nil=>S.Nil
      |S.Cons(y,yr)=>case L.force zs of S.Nil=>S.Nil|S.Cons(z,zr)=>
        L.force(headstrict force(S.cons(L.delay(fn()=>f(L.force w)(L.force x)(L.force y)(L.force z)),lift41 force f wr xr yr zr))))
  fun bit1 f x=case x of 0=>f 0|1=>f 1|_=>raise Match
  fun bit2 f x y=case(x,y)of(0,0)=>f(0,0)|(0,1)=>f(0,1)|(1,0)=>f(1,0)|(1,1)=>f(1,1)|_=>raise Match
  val inv=lift11 forceBit(fn x=>bit1(fn 0=>1|_=>0)x)
  val and2=lift21 forceBit(fn x=>fn y=>bit2(fn(a,b)=>if a=1 andalso b=1 then 1 else 0)x y)
  val nand2=lift21 forceBit(fn x=>fn y=>bit2(fn(a,b)=>if a=1 andalso b=1 then 0 else 1)x y)
  val or2=lift21 forceBit(fn x=>fn y=>bit2(fn(a,b)=>if a=1 orelse b=1 then 1 else 0)x y)
  val nor2=lift21 forceBit(fn x=>fn y=>bit2(fn(a,b)=>if a=1 orelse b=1 then 0 else 1)x y)
  val xor=lift21 forceBit(fn x=>fn y=>bit2(fn(a,b)=>if a=b then 0 else 1)x y)
  val or3=lift31 forceBit(fn x=>fn y=>fn z=>
    bit1(fn a=>bit2(fn(b,c)=>if a=1 orelse b=1 orelse c=1 then 1 else 0)y z)x)
  fun bmux1 c a b=or2(and2(inv c)a)(and2 c b)
  fun word11 n f xs=L.delay(fn()=>if n=0 then S.Nil else
    S.Cons(L.delay(fn()=>f(L.delay(fn()=>L.force(S.head xs)))),L.delay(fn()=>L.force(word11(n-1)f(L.delay(fn()=>L.force(S.tail xs)))))))
  fun word21 n f xs ys=L.delay(fn()=>if n=0 then S.Nil else
    S.Cons(L.delay(fn()=>f(L.delay(fn()=>L.force(S.head xs)))(L.delay(fn()=>L.force(S.head ys)))),
      L.delay(fn()=>L.force(word21(n-1)f(L.delay(fn()=>L.force(S.tail xs)))(L.delay(fn()=>L.force(S.tail ys)))))))
  fun word31 n f xs ys zs=L.delay(fn()=>if n=0 then S.Nil else
    S.Cons(L.delay(fn()=>f(L.delay(fn()=>L.force(S.head xs)))(L.delay(fn()=>L.force(S.head ys)))(L.delay(fn()=>L.force(S.head zs)))),
      L.delay(fn()=>L.force(word31(n-1)f(L.delay(fn()=>L.force(S.tail xs)))(L.delay(fn()=>L.force(S.tail ys)))(L.delay(fn()=>L.force(S.tail zs)))))))
  fun wmux1 n c left right=word21 n(bmux1 c)left right
  fun wlat n values=L.delay(fn()=>if n=0 then S.Nil else case L.force values of S.Nil=>raise Match
    |S.Cons(x,rest)=>S.Cons(L.delay(fn()=>latch(L.delay(fn()=>L.force(L.force x)))),wlat(n-1)rest))
  fun rept n x=L.delay(fn()=>if n=0 then S.Nil else S.Cons(L.delay(fn()=>x),rept(n-1)x))
  fun take n xs=L.delay(fn()=>if n<=0 then S.Nil else case L.force xs of S.Nil=>S.Nil
    |S.Cons(x,rest)=>S.Cons(x,take(n-1)rest))
  fun drop n xs=if n<=0 then xs else drop(n-1)(S.tail xs)
  fun length xs=let fun loop n values=case L.force values of S.Nil=>n|S.Cons(_,rest)=>loop(n+1)rest
    in loop 0 xs end
  fun wideGate f xs=
    let val count=L.delay(fn()=>length xs)
        val result=L.delay(fn()=>case L.force xs of S.Nil=>raise Fail "empty wide gate"
          |S.Cons(x,rest)=>case L.force rest of S.Nil=>L.force x
            |_=>let val middle=L.force count div 2
              in f(L.delay(fn()=>L.force(wideGate f(take middle xs))))
                  (L.delay(fn()=>L.force(wideGate f(drop middle xs))))end)
    in L.delay(fn()=>L.force(L.force result))end
  val wideAnd=wideGate and2
  val wideOr=wideGate or2
  val wideNand=wideGate nand2
  val wideNor=wideGate nor2
  fun regIs0 n xs=wideAnd(S.map inv xs)
  fun shl n xs=S.append(L.delay(fn()=>L.force(S.tail xs)))(S.singleton zero)
  fun shr n xs=S.cons(L.delay(fn()=>zero),take(n-1)xs)
  fun halfadd x y=(and2 x y,xor x y)
  fun fulladd a b c=let val(w,x)=halfadd a b val(y,z)=halfadd x c in(or2 w y,z)end
  fun add n xs ys cin=
    let val result=L.delay(fn()=>if n=0 then(cin,S.empty())else if n<0 then raise Fail "Main.add < 0"
          else case(L.force xs,L.force ys)of(S.Cons(x,xr),S.Cons(y,yr))=>
            let val pair=L.delay(fn()=>add(n-1)xr yr cin)
                val carry=L.delay(fn()=>L.force(#1(L.force pair)))
                val current=L.delay(fn()=>fulladd(L.delay(fn()=>L.force(L.force x)))
                    (L.delay(fn()=>L.force(L.force y)))carry)
            in(L.delay(fn()=>L.force(#1(L.force current))),
                S.cons(L.delay(fn()=> #2(L.force current)),L.delay(fn()=>L.force(#2(L.force pair)))))end
          |_=>raise Match)
    in(L.delay(fn()=>L.force(#1(L.force result))),L.delay(fn()=>L.force(#2(L.force result))))end
  fun ibits n value=
    let fun bits 0 _=[]|bits n i=i mod 2::bits(n-1)(i div 2)
    in S.fromList(rev(bits n value))end
  fun ntrans n rows=L.delay(fn()=>if n=0 then S.Nil else
    S.Cons(L.delay(fn()=>S.map S.head rows),ntrans(n-1)(S.map S.tail rows)))
  fun gated start values=L.delay(fn()=>case L.force start of S.Nil=>S.Nil
    |S.Cons(bit,rest)=>case L.force values of S.Nil=>S.Nil|S.Cons(x,xs)=>
      case L.force bit of 0=>S.Cons(L.delay(fn()=>0),gated rest values)
       |1=>S.Cons(x,gated rest xs)|_=>raise Match)
  fun multiplier width start a b=
    let val holder=ref(NONE:(bit*word*word*word)option)
        fun get()=valOf(!holder)
        val regP=S.fix(fn _=>L.force(wlat(2*width)(wmux1(2*width)start
          (L.delay(fn()=>L.force(#4(get()))))(rept(2*width)zero))))
        val regA=S.fix(fn self=>L.force(wlat(2*width)(wmux1(2*width)start(shl(2*width)self)(S.append(rept width zero)a))))
        val regB=S.fix(fn self=>L.force(wlat width(wmux1 width start(shr width self)b)))
        val lsbB=L.delay(fn()=>L.force(S.head(drop(width-1)regB)))
        val sum=L.delay(fn()=>L.force(#2(add(2*width)regP(wmux1(2*width)lsbB(rept(2*width)zero)regA)zero)))
        val ready=or2(regIs0(2*width)regA)(regIs0 width regB)
        val _=holder:=SOME(ready,regA,regB,sum)
    in(ready,regA,regB,regP)end
  fun multsys width(pairs:(int*int)S.stream)=
    let val holder=ref NONE
        val start=L.delay(fn()=>L.force(valOf(!holder)))
        fun f values=ntrans width(S.map(ibits width)(gated start values))
        val a=f(S.map #1 pairs)val b=f(S.map #2 pairs)
        val(ready,ra,rb,prod)=multiplier width start a b
        val _=holder:=SOME ready
    in(a,b,ready,ra,rb,prod)end
  fun trans rows=L.delay(fn()=>
    let fun anyEmpty xs=case L.force xs of S.Nil=>false|S.Cons(row,rest)=>
          (case L.force(L.force row)of S.Nil=>true|_=>anyEmpty rest)
    in if anyEmpty rows then S.Nil else S.Cons(L.delay(fn()=>S.map S.head rows),trans(S.map S.tail rows))end)
  fun bitsi bits=S.foldl(fn(b,n)=>Word64.+(Word64.*(n,0w2),Word64.fromInt b))(0w0:Word64.word)bits
  fun intrep word=S.map bitsi(trans word)
  fun signed word=let val n=Word64.toLargeIntX word
    in if n<0 then "-"^IntInf.toString(~n)else IntInf.toString n end
  fun dec width str=if String.size str<width then String.implode(List.tabulate(width-String.size str,fn _=> #" "))^str else str
  fun fmtW width xs=S.map(fn n=>dec width(signed n))(intrep xs)
  fun fmtB bits=S.map(fn n=>dec 1(Int.toString n))bits
  fun fmtStr s=S.fix(fn self=>S.Cons(L.delay(fn()=>s),self))
  fun inputs n=S.cons(L.delay(fn()=>(2+3*n,11+2*n)),L.delay(fn()=>L.force(inputs(n+1))))
  fun indexes n=S.cons(L.delay(fn()=>n),L.delay(fn()=>L.force(indexes(n+1))))
  fun trace width limit=
    let val(a,b,ready,ra,rb,prod)=multsys width(inputs 1)
        val fields=S.fromList[S.map(fn n=>dec 5(Int.toString n))(indexes 0),fmtStr". ",fmtB ready,
          fmtW 10 a,fmtW 10 b,fmtStr"  ==> ",fmtB ready,fmtW 10 ra,fmtW 10 rb,fmtW 10 prod,fmtStr"\n"]
        val rows=take limit(S.map(fn row=>String.concat(rev(S.foldl(fn(s,ss)=>s::ss)[]row)))(trans fields))
    in S.append(S.fromList(String.explode "Binary multiplier circuit simulation\n"))
      (S.concatMap(fn row=>S.fromList(String.explode row))rows)end
  fun runMult width limit pairs=
    let val(_,_,ready,_,_,_)=multsys width pairs
    in S.foldl(fn(bit,total)=>bit+total)0(take limit ready)end
  fun readyCount width limit=runMult width limit(inputs 1)

end
