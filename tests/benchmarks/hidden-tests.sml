
structure NeedHidden=BenchHiddenFn(BenchNeed)
structure NeedParse=BenchHiddenParseFn(NeedHidden)
structure NeedDriver=BenchHiddenDriverFn(structure K=NeedHidden structure Parser=NeedParse)
structure NeedTests=struct
  structure K=NeedHidden
  structure Parser=NeedParse
  structure Driver=NeedDriver
  structure D=BenchNeed
  structure S=BenchStream
  structure L=BenchLazy
  fun toList values=case L.force values of S.Nil=>[]|S.Cons(x,rest)=>L.force x::toList rest
  val mode="Need"
  fun label s="hidden/"^mode^"/"^s
  fun read path=Driver.read path
  fun words text=List.map Driver.word(String.tokens Char.isSpace text)
  fun point value=List.map(fn n=>K.N.bits(D.force n))[K.x value,K.y value,K.z value]
  fun row edge=point(K.support edge)@point(K.terminal edge)
  fun check(profile,file)=
    let val faces=Parser.scene(read file)
        val view=Parser.view "2,10,3"
        val edges=K.prepare view faces
        val expected=List.map words(String.tokens(fn c=>c= #"\n")(read(profile^".edges")))
        val _=T.check(label(profile^"-complete-edge-bits"),fn()=>
          List.map row(toList edges)=expected)
        val(text,count)=Driver.render(K.plot edges)(Driver.reference(read(profile^".commands")))
        val _=T.check(label(profile^"-render-consumes-all-edges"),fn()=>count=List.length expected)
        val _=T.check(label(profile^"-forward-reverse-hash"),fn()=>Driver.hash text=Driver.hashReference text)
        val rotated=S.concatMap(fn face=>S.map(K.rotate view)face)faces
        val wanted=List.map words(String.tokens(fn c=>c= #"\n")(read(profile^".rotated")))
        val _=T.check(label(profile^"-rotated-vertex-bits"),fn()=>List.map point(toList rotated)=wanted)
    in()end
  val _=List.app check[("smoke","houses.plate"),("normal","rad.plate"),("large","four.plate")]
  fun n a=K.N.literal a
  val epsilon=n 0.0001
  val zero=K.N.zero
  val _=T.check(label"epsilon-equality-is-false",fn()=>not(K.N.eq(epsilon,zero)))
  val _=T.check(label"epsilon-inequality-is-also-false",fn()=>not(K.N.ne(epsilon,zero)))
  val _=T.check(label"epsilon-order-GT",fn()=>K.N.compare(epsilon,zero)=GREATER
    andalso not(K.N.lt(epsilon,zero))andalso not(K.N.le(epsilon,zero))
    andalso K.N.gt(epsilon,zero)andalso K.N.ge(epsilon,zero))
  val _=T.check(label"reverse-epsilon-order-LT",fn()=>K.N.compare(zero,epsilon)=LESS
    andalso not(K.N.lt(zero,epsilon))andalso K.N.le(zero,epsilon)
    andalso not(K.N.gt(zero,epsilon))andalso not(K.N.ge(zero,epsilon)))
  val _=T.check(label"vector-inequality-complements-vector-equality",fn()=>
    not(K.equal(K.vec[epsilon,zero,zero],K.vec[zero,zero,zero])))
  val _=T.check(label"below-epsilon-equal",fn()=>K.N.eq(n 0.00009999,zero))
  val _=T.check(label"binary32-positive-zero",fn()=>K.N.bits 0.0=0w0)
  val _=T.check(label"binary32-negative-zero",fn()=>K.N.bits(~0.0)=0wx80000000)
  val _=T.check(label"binary32-epsilon",fn()=>K.N.bits(D.force epsilon)=0w953267991)
  val _=T.check(label"binary32-round-tie-even",fn()=>
    Real.==(BenchMandelSingle.round 1.000000059604644775390625,1.0))
  val _=T.check(label"binary32-subnormal-rejected",fn()=>
    ((K.N.bits 1.0E~40;false)handle Fail _=>true))
  val _=T.check(label"binary32-nonfinite-rejected",fn()=>
    ((K.N.bits(1.0/0.0);false)handle Fail _=>true))
  val _=T.check(label"binary32-nonrepresentable-rejected",fn()=>
    ((K.N.bits 1.1;false)handle Fail _=>true))
  val _=T.check(label"view-zero-identity",fn()=>
    point(K.rotate K.zeroVector(K.vec(List.map n[1.0,2.0,3.0])))=point(K.vec(List.map n[1.0,2.0,3.0])))
  val _=T.check(label"view-plus-z-identity",fn()=>
    point(K.rotate K.zVector(K.vec(List.map n[1.0,2.0,3.0])))=point(K.vec(List.map n[1.0,2.0,3.0])))
  val _=T.check(label"view-minus-z-negates-every-coordinate",fn()=>
    point(K.rotate K.minusZVector(K.vec(List.map n[1.0,2.0,3.0])))=point(K.vec(List.map n[~1.0,~2.0,~3.0])))
  val _=T.check(label"right-rotated-polygon-edge",fn()=>
    let val face=S.fromList(List.map(fn x=>K.vec(List.map n x))[[0.0,0.0,0.0],[2.0,0.0,0.0],[0.0,2.0,0.0]])
        val plate=S.head(K.makeObject(S.singleton face))
        val first=S.head(K.plateEdges plate)
    in row first=[0w0,0w0,0w0,0w0,0w1073741824,0w0]end)
  val _=T.check(label"fresh-triangular-memo-is-lazy-and-shared",fn()=>
    let val calls=ref 0
        val a=K.Plate(1,S.empty())val b=K.Plate(2,S.empty())val c=K.Plate(3,S.empty())
        val memo=K.makeMemo(fn _=>fn _=>(calls:= !calls+1;true))(S.fromList[a,b,c])
        val fresh= !calls=0
        val first=K.lazyAbove memo c a
        val second=K.lazyAbove memo c a
        val reverse=K.lazyAbove memo a c
        val diagonal=K.lazyAbove memo a a
    in fresh andalso first andalso second andalso not reverse andalso not diagonal andalso !calls=1 end)
  val _=T.check(label"driver-repetition-reset",fn()=>Driver.run["2","houses.plate","2,10,3","smoke.commands"]="2:50")
  val _=T.check(label"driver-zero-repetitions",fn()=>Driver.run["0","houses.plate","2,10,3","smoke.commands"]="0:0")
  val _=List.app(fn filename=>T.check(label("reject-"^filename),fn()=>
    ((Driver.run["1","houses.plate","2,10,3",filename];false)handle Fail _=>true)))
    ["wrong.commands","empty.commands","extra.commands","wrong-topology.commands","invalid.commands"]
  val _=List.app(fn text=>T.check(label("reject-scene-"^text),fn()=>
    ((toList(Parser.scene text);false)handle Fail _=>true)))
    ["not a scene","[vec[1,2]]","[vec[1,2,3,4]]","[vec[1,2,3]] trailing","[vec[.]]"]
  val _=List.app(fn text=>T.check(label("reject-view-"^text),fn()=>
    ((Parser.view text;false)handle Fail _=>true)))["1,2","1,2,3,4","1,2,3 trailing"]
  val _=List.app(fn(text,wanted)=>T.check(label("golden-hash-"^text),fn()=>
    Driver.hash text=Word64.fromInt wanted))[("",0),("a",97),("abc",96354)]
  val _=List.app(fn text=>T.check(label("hash-"^text),fn()=>Driver.hash text=Driver.hashReference text))
    ["","a","abcdefghijklmnopqrstuvwxyz","01234567890123456789012345678901234567890123456789012345678901234567890123456789"]
end

structure StrictHidden=BenchHiddenFn(BenchStrict)
structure StrictParse=BenchHiddenParseFn(StrictHidden)
structure StrictDriver=BenchHiddenDriverFn(structure K=StrictHidden structure Parser=StrictParse)
structure StrictTests=struct
  structure K=StrictHidden
  structure Parser=StrictParse
  structure Driver=StrictDriver
  structure D=BenchStrict
  structure S=BenchStream
  structure L=BenchLazy
  fun toList values=case L.force values of S.Nil=>[]|S.Cons(x,rest)=>L.force x::toList rest
  val mode="Strict"
  fun label s="hidden/"^mode^"/"^s
  fun read path=Driver.read path
  fun words text=List.map Driver.word(String.tokens Char.isSpace text)
  fun point value=List.map(fn n=>K.N.bits(D.force n))[K.x value,K.y value,K.z value]
  fun row edge=point(K.support edge)@point(K.terminal edge)
  fun check(profile,file)=
    let val faces=Parser.scene(read file)
        val view=Parser.view "2,10,3"
        val edges=K.prepare view faces
        val expected=List.map words(String.tokens(fn c=>c= #"\n")(read(profile^".edges")))
        val _=T.check(label(profile^"-complete-edge-bits"),fn()=>
          List.map row(toList edges)=expected)
        val(text,count)=Driver.render(K.plot edges)(Driver.reference(read(profile^".commands")))
        val _=T.check(label(profile^"-render-consumes-all-edges"),fn()=>count=List.length expected)
        val _=T.check(label(profile^"-forward-reverse-hash"),fn()=>Driver.hash text=Driver.hashReference text)
        val rotated=S.concatMap(fn face=>S.map(K.rotate view)face)faces
        val wanted=List.map words(String.tokens(fn c=>c= #"\n")(read(profile^".rotated")))
        val _=T.check(label(profile^"-rotated-vertex-bits"),fn()=>List.map point(toList rotated)=wanted)
    in()end
  val _=List.app check[("smoke","houses.plate"),("normal","rad.plate"),("large","four.plate")]
  fun n a=K.N.literal a
  val epsilon=n 0.0001
  val zero=K.N.zero
  val _=T.check(label"epsilon-equality-is-false",fn()=>not(K.N.eq(epsilon,zero)))
  val _=T.check(label"epsilon-inequality-is-also-false",fn()=>not(K.N.ne(epsilon,zero)))
  val _=T.check(label"epsilon-order-GT",fn()=>K.N.compare(epsilon,zero)=GREATER
    andalso not(K.N.lt(epsilon,zero))andalso not(K.N.le(epsilon,zero))
    andalso K.N.gt(epsilon,zero)andalso K.N.ge(epsilon,zero))
  val _=T.check(label"reverse-epsilon-order-LT",fn()=>K.N.compare(zero,epsilon)=LESS
    andalso not(K.N.lt(zero,epsilon))andalso K.N.le(zero,epsilon)
    andalso not(K.N.gt(zero,epsilon))andalso not(K.N.ge(zero,epsilon)))
  val _=T.check(label"vector-inequality-complements-vector-equality",fn()=>
    not(K.equal(K.vec[epsilon,zero,zero],K.vec[zero,zero,zero])))
  val _=T.check(label"below-epsilon-equal",fn()=>K.N.eq(n 0.00009999,zero))
  val _=T.check(label"binary32-positive-zero",fn()=>K.N.bits 0.0=0w0)
  val _=T.check(label"binary32-negative-zero",fn()=>K.N.bits(~0.0)=0wx80000000)
  val _=T.check(label"binary32-epsilon",fn()=>K.N.bits(D.force epsilon)=0w953267991)
  val _=T.check(label"binary32-round-tie-even",fn()=>
    Real.==(BenchMandelSingle.round 1.000000059604644775390625,1.0))
  val _=T.check(label"binary32-subnormal-rejected",fn()=>
    ((K.N.bits 1.0E~40;false)handle Fail _=>true))
  val _=T.check(label"binary32-nonfinite-rejected",fn()=>
    ((K.N.bits(1.0/0.0);false)handle Fail _=>true))
  val _=T.check(label"binary32-nonrepresentable-rejected",fn()=>
    ((K.N.bits 1.1;false)handle Fail _=>true))
  val _=T.check(label"view-zero-identity",fn()=>
    point(K.rotate K.zeroVector(K.vec(List.map n[1.0,2.0,3.0])))=point(K.vec(List.map n[1.0,2.0,3.0])))
  val _=T.check(label"view-plus-z-identity",fn()=>
    point(K.rotate K.zVector(K.vec(List.map n[1.0,2.0,3.0])))=point(K.vec(List.map n[1.0,2.0,3.0])))
  val _=T.check(label"view-minus-z-negates-every-coordinate",fn()=>
    point(K.rotate K.minusZVector(K.vec(List.map n[1.0,2.0,3.0])))=point(K.vec(List.map n[~1.0,~2.0,~3.0])))
  val _=T.check(label"right-rotated-polygon-edge",fn()=>
    let val face=S.fromList(List.map(fn x=>K.vec(List.map n x))[[0.0,0.0,0.0],[2.0,0.0,0.0],[0.0,2.0,0.0]])
        val plate=S.head(K.makeObject(S.singleton face))
        val first=S.head(K.plateEdges plate)
    in row first=[0w0,0w0,0w0,0w0,0w1073741824,0w0]end)
  val _=T.check(label"fresh-triangular-memo-is-lazy-and-shared",fn()=>
    let val calls=ref 0
        val a=K.Plate(1,S.empty())val b=K.Plate(2,S.empty())val c=K.Plate(3,S.empty())
        val memo=K.makeMemo(fn _=>fn _=>(calls:= !calls+1;true))(S.fromList[a,b,c])
        val fresh= !calls=0
        val first=K.lazyAbove memo c a
        val second=K.lazyAbove memo c a
        val reverse=K.lazyAbove memo a c
        val diagonal=K.lazyAbove memo a a
    in fresh andalso first andalso second andalso not reverse andalso not diagonal andalso !calls=1 end)
  val _=T.check(label"driver-repetition-reset",fn()=>Driver.run["2","houses.plate","2,10,3","smoke.commands"]="2:50")
  val _=T.check(label"driver-zero-repetitions",fn()=>Driver.run["0","houses.plate","2,10,3","smoke.commands"]="0:0")
  val _=List.app(fn filename=>T.check(label("reject-"^filename),fn()=>
    ((Driver.run["1","houses.plate","2,10,3",filename];false)handle Fail _=>true)))
    ["wrong.commands","empty.commands","extra.commands","wrong-topology.commands","invalid.commands"]
  val _=List.app(fn text=>T.check(label("reject-scene-"^text),fn()=>
    ((toList(Parser.scene text);false)handle Fail _=>true)))
    ["not a scene","[vec[1,2]]","[vec[1,2,3,4]]","[vec[1,2,3]] trailing","[vec[.]]"]
  val _=List.app(fn text=>T.check(label("reject-view-"^text),fn()=>
    ((Parser.view text;false)handle Fail _=>true)))["1,2","1,2,3,4","1,2,3 trailing"]
  val _=List.app(fn(text,wanted)=>T.check(label("golden-hash-"^text),fn()=>
    Driver.hash text=Word64.fromInt wanted))[("",0),("a",97),("abc",96354)]
  val _=List.app(fn text=>T.check(label("hash-"^text),fn()=>Driver.hash text=Driver.hashReference text))
    ["","a","abcdefghijklmnopqrstuvwxyz","01234567890123456789012345678901234567890123456789012345678901234567890123456789"]
end

structure HiddenDemandTests=struct
  structure K=NeedHidden
  structure Q=StrictHidden
  val _=T.check("hidden/lazy-vector-skips-unused-coordinate",fn()=>
    let val calls=ref 0
        val value=K.constructed[fn()=>K.N.literal 1.0,fn()=>K.N.literal 2.0,
          fn()=>(calls:= !calls+1;K.N.literal 3.0)]
    in Real.==(BenchNeed.force(K.x value),1.0)andalso !calls=0 end)
  val _=T.check("hidden/strict-vector-forces-finite-coordinates",fn()=>
    let val calls=ref 0
        val value=Q.constructed[fn()=>Q.N.literal 1.0,fn()=>Q.N.literal 2.0,
          fn()=>(calls:= !calls+1;Q.N.literal 3.0)]
    in Real.==(BenchStrict.force(Q.x value),1.0)andalso !calls=1 end)
  val _=T.check("hidden/lazy-coordinate-is-memoized",fn()=>
    let val calls=ref 0
        val value=K.constructed[fn()=>(calls:= !calls+1;K.N.literal 1.0),fn()=>K.N.zero,fn()=>K.N.zero]
        val a=BenchNeed.force(K.x value)val b=BenchNeed.force(K.x value)
    in Real.==(a,b)andalso !calls=1 end)
  val _=T.check("hidden/plot-leaves-irrelevant-z-delayed",fn()=>
    let val calls=ref 0
        val p=K.vec[K.N.literal 1.0,K.N.literal 2.0,
          BenchNeed.delay(fn()=>(calls:= !calls+1;3.0))]
        val e=K.edgeT p(K.vec(List.map K.N.literal[2.0,3.0,4.0]))
        val first=BenchStream.head(K.plot(BenchStream.singleton e))
    in case first of K.Move(x,y)=>
        Real.==(BenchNeed.force x,1.0)andalso Real.==(BenchNeed.force y,2.0)andalso !calls=0
      |_=>false end)
end
