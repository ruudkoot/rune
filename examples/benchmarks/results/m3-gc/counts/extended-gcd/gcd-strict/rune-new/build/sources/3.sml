structure Benchmark =
struct
  val name="gcd-strict"
  fun calculate d=
    let val ns=List.tabulate(d+1,fn i=>IntInf.fromInt(5000+i))
        val ms=List.tabulate(d+1,fn i=>IntInf.fromInt(10000+i))
        val pairs=List.concat(List.map(fn x=>List.map(fn y=>(x,y))ms)ns)
        val triples=List.map(fn(x,y)=>(x,y,BenchExtendedGCD.strict x y))pairs
        val values=List.map BenchExtendedGCD.consume triples
        fun largest[x]=x|largest(x::y::rest)=largest((if x<y then y else x)::rest)
          |largest[]=raise Empty
    in largest values end
  fun run args=BenchExtendedGCD.run calculate args
end
