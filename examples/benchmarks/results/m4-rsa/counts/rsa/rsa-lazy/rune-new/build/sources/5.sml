(* The nofib Rsa.hs recurrence and base-128 block encoding, with explicit demand. *)
functor BenchRsaFn (D : BENCH_SUSPEND) =
struct
  val modulus : IntInf.int = 2036450659413645137870851576872812267542175329986469156678671505255564383842535488743101632280716717779536712424613501441720195827856504007305662157107
  val exponent : IntInf.int = 387784473137902876992546516170169092918207676456888779623592396031349415024943784869634893342729620092877891356118467738167515879252473323905128540213
  fun power n m base =
    if n=0 then IntInf.fromInt 1
    else if IntInf.mod(n,2)=0 then
      let val result = power (IntInf.div(n,2)) m base
      in IntInf.mod(IntInf.*(result,result),m) end
    else IntInf.mod(IntInf.*(D.force base,power (IntInf.-(n,1)) m base),m)
  fun code input =
    let fun loop i accumulated = if i=String.size input then accumulated else
          loop(i+1)(D.delay(fn () =>
            IntInf.+(IntInf.*(128,D.force accumulated),IntInf.fromInt(Char.ord(String.sub(input,i))))))
    in loop 0 (D.delay(fn () => IntInf.fromInt 0)) end
  val blockSize = String.size(IntInf.toString modulus)*47 div 100
  datatype node = Nil | Cons of string D.t * node D.t
  fun encryptFrom input index = D.delay(fn () =>
    if index=String.size input then Nil else
    let val count = Int.min(blockSize,String.size input-index)
        val block = String.substring(input,index,count)
        val text = D.delay(fn () => IntInf.toString(power exponent modulus (code block)) ^ "\n")
    in Cons(text,encryptFrom input (index+count)) end)
  fun encrypt input =
    let fun collect stream texts = case D.force stream of Nil => String.concat(List.rev texts)
          | Cons(text,rest) => collect rest (D.force text :: texts)
    in collect (encryptFrom input 0) [] end
end
