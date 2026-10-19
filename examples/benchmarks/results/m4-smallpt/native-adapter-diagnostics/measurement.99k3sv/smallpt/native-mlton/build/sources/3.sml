structure SmallptCheck =
struct
  structure K=BenchSmallpt
  fun real text=case Real.fromString text of SOME x=>
    if Real.isFinite x then x else raise Fail "nonfinite scene reference"
    |NONE=>raise Fail "invalid scene reference"
  fun line input=case TextIO.inputLine input of SOME s=>s|NONE=>raise Fail "short scene reference"
  fun run width height samples path=
    let val input=TextIO.openIn path
        val expectedSum=real(line input)
        val count=ref 0 val total=ref 0.0
        fun pixel(r,g,b)=
          let val fields=List.map real(String.tokens Char.isSpace(line input))
              fun near(actual,wanted)=BenchInput.closeReal(actual,wanted,1.0E~8,1.0E~8)
              val _=case fields of[x,y,z]=>
                if near(r,x)andalso near(g,y)andalso near(b,z)then()
                else raise Fail "incorrect result: rendered pixel differs"
                |_=>raise Fail "invalid scene pixel reference"
          in count:= !count+1;total:= !total+r+g+b end
        fun row _ values=List.app pixel values
        val _=K.render width height samples row handle ex=>(TextIO.closeIn input;raise ex)
        val extra=TextIO.inputLine input val _=TextIO.closeIn input
    in if !count=width*height andalso not(Option.isSome extra)andalso
      BenchInput.closeReal(!total,expectedSum,1.0E~6,1.0E~10)then()
      else raise Fail "incorrect result: scene size or channel sum differs"end
end
