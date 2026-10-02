structure Benchmark =
struct
  val name="kitloop2"
  fun kernel maxint =
    let fun is_zero(0,0)=true | is_zero _=false
        fun sub(m,n)=if n=0 then(m-1,maxint) else(m,n-1)
        fun loop(x as(m,n))=if is_zero x then x else loop(sub x)
    in loop(maxint,maxint) end
  fun run [size] =
    let val n=BenchInput.between(0,2000)(BenchInput.integer size)
        val(a,b)=kernel n
    in if a=0 andalso b=0 then Int.toString a^" "^Int.toString b else raise Fail "counter loop" end
  | run _=raise Fail "kitloop2 expects paired-counter maximum"
end
