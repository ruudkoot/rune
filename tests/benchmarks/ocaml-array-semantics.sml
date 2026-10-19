structure BenchArrayTests =
struct
  structure R = BenchOCamlRandom
  structure K = BenchOCamlArrayKernels
  fun lines path function =
    let val input=TextIO.openIn path
        fun loop () = case TextIO.inputLine input of NONE => true
          | SOME line => function line andalso loop()
        val ok=loop()
        val _=TextIO.closeIn input
    in ok end
  fun sample seed name =
    let val state=seed()
    in lines ("random-"^name^"-bits.txt") (fn text => R.bits state=valOf(Int.fromString text))end
  fun bounded seed name bound =
    let val state=seed()
    in lines ("random-"^name^"-"^Int.toString bound^".txt")
      (fn text => R.integer state bound=valOf(Int.fromString text))end
  fun floats seed name =
    let val state=seed()
    in lines ("random-"^name^"-float.txt") (fn text =>
      BenchInput.closeReal(R.real state 100.0,valOf(Real.fromString text),5.0E~14,1.0E~15))end
  val seeds=[("default",R.default),("42",R.seed42),("512",R.seed512)]
  val _=List.app(fn(name,seed) =>
    (T.check("ocaml-random/"^name^"-bits",fn()=>sample seed name);
     T.check("ocaml-random/"^name^"-rejection",fn()=>bounded seed name 1000000000);
     T.check("ocaml-random/"^name^"-bound-one",fn()=>bounded seed name 1);
     T.check("ocaml-random/"^name^"-float",fn()=>floats seed name)))seeds
  val _=T.check("ocaml-random/zero-bound",fn()=>((R.integer(R.default())0;false)handle Domain=>true))
  val _=T.check("ocaml-random/negative-bound",fn()=>((R.integer(R.default())~1;false)handle Domain=>true))
  val _=T.check("ocaml-random/fresh-states",fn()=>R.bits(R.default())=R.bits(R.default()))
  val _=T.check("ocaml-random/float-check-rejects-perturbation",fn()=>
    not(BenchInput.closeReal(1.0,1.000001,5.0E~14,1.0E~15)))
  fun insert x [] = [x] | insert x(y::ys)=if x<=y then x::y::ys else y::insert x ys
  fun sorted xs=List.foldl(fn(x,ys)=>insert x ys)[]xs
  fun exercise xs =
    let val a=Array.fromList xs
        val b=Array.fromList xs
        val _=K.quicksort a 0(Array.length a-1)
        val _=K.mergesort b
    in Array.foldr op:: [] a=sorted xs andalso Array.foldr op:: [] b=sorted xs end
  val _=T.check("array-sorts/empty-singleton-equal",fn()=>List.all exercise[[],[1],[2,2,2,2]])
  val _=T.check("array-sorts/thresholds-and-odd-lengths",fn()=>List.all
    (fn n=>exercise(List.tabulate(n,fn i=>(i*37+11)mod 97)))[1,2,3,31,32,33,63,64,65,101])
  val _=T.check("array-sorts/descending-and-negative",fn()=>exercise[4,3,2,1,0,~1,~2])
  val _=T.check("matrix-multiply/rectangular",fn()=>
    let val x=Array.fromList[Array.fromList[1,2,3],Array.fromList[4,5,6]]
        val y=Array.fromList[Array.fromList[7,8],Array.fromList[9,10],Array.fromList[11,12]]
        val answer=Array.tabulate(2,fn _=>Array.array(2,0))
        val _=K.multiply answer x y
    in Array.foldr(fn(row,rest)=>Array.foldr op:: [] row::rest)[]answer=[[58,64],[139,154]]end)
  val _=T.check("floyd-warshall/paths-and-disconnected-vertex",fn()=>
    let val inf=K.Infinity
        fun v n=K.Value n
        val a=Array.fromList(List.map Array.fromList
          [[v 0,v 5,v 20,inf],[inf,v 0,v 3,inf],[inf,inf,v 0,inf],[inf,inf,inf,v 0]])
        val _=K.floyd a
    in Array.sub(Array.sub(a,0),2)=v 8 andalso Array.sub(Array.sub(a,0),3)=inf end)
end
