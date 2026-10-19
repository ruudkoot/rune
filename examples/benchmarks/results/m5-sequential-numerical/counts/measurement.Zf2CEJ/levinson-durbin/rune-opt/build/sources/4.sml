structure BenchLevinsonFiles =
struct
  type reference={label:string,ar:RealArray.array,sigma:real}
  fun tokens path =
    let val input=TextIO.openIn path val text=TextIO.inputAll input
    in TextIO.closeIn input;String.tokens Char.isSpace text end
  fun real text = case Real.fromString text of SOME x=>
      if Real.isFinite x then x else raise Fail "nonfinite Levinson reference"
    | NONE=>raise Fail "invalid Levinson reference real"
  fun data path = case tokens path of []=>raise Fail "empty PCM input"
    | size::values=>
      let val count=BenchInput.integer size
          val samples=List.map(fn text=>Real.fromInt
            (BenchInput.between(~32768,32767)(BenchInput.integer text))/32768.0)values
      in if List.length samples=count then RealArray.fromList samples
         else raise Fail "PCM input length differs" end
  fun references path =
    let fun values 0 rest acc=(RealArray.fromList(List.rev acc),rest)
          | values n (x::xs) acc=values(n-1)xs(real x::acc)
          | values _ [] _=raise Fail "short Levinson reference"
        fun loop [] acc=List.rev acc
          | loop(label::size::sigma::rest)acc=
            let val count=BenchInput.between(1,10001)(BenchInput.integer size)
                val(ar,remaining)=values count rest []
            in loop remaining({label=label,ar=ar,sigma=real sigma}::acc)end
          | loop _ _=raise Fail "invalid Levinson reference header"
    in loop(tokens path)[] end
  fun check ({ar=expected,sigma=variance,...}:reference) (actual,sigma) =
    let val n=RealArray.length expected
        val _=if RealArray.length actual=n andalso
          BenchInput.closeReal(sigma,variance,2.0E~10,2.0E~9)
          then ()else raise Fail "Levinson variance or length differs"
        fun loop i=if i=n then ()else
          if BenchInput.closeReal(RealArray.sub(actual,i),RealArray.sub(expected,i),2.0E~9,2.0E~8)
          then loop(i+1)else raise Fail "Levinson coefficient differs"
    in loop 0 end
  val labels=["a","i","u","e","o"]
  fun validate order datasets expected =
    let fun loop [] [] []=()
          | loop(label::labels)(data::datasets)((reference:reference)::rest)=
            if #label reference=label andalso RealArray.length(#ar reference)=order+1
            then (check reference (BenchLevinson.coefficients data order);loop labels datasets rest)
            else raise Fail "Levinson reference profile differs"
          | loop _ _ _=raise Fail "Levinson reference set differs"
    in loop labels datasets expected end
end
