(* SML97 result consumer; state arrays and all 27 numerical moments are checked. *)
structure BenchAlmaDriver =
struct
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
    val _=TextIO.closeIn f in text end
  fun real text=case Real.fromString text of SOME v=>if Real.isFinite v then v
    else raise Fail "nonfinite almabench reference"|NONE=>raise Fail "invalid almabench real"
  fun reference text=List.map real(String.tokens Char.isSpace text)
  fun valid(actual,wanted)=List.length actual=27 andalso List.length wanted=27 andalso
    ListPair.allEq(fn(a,b)=>BenchInput.closeReal(a,b,1.0E~6,1.0E~10))(actual,wanted)
  fun run[loopsText,daysText,path]=
    let val loops=BenchInput.between(0,20)(BenchInput.integer loopsText)
        val days=BenchInput.between(0,36525)(BenchInput.integer daysText)
        val wanted=reference(read path)
        val jd=RealArray.fromList[BenchAlmaTables.j2000,1.0]
        val pv=Array.fromList[RealArray.array(3,0.0),RealArray.array(3,0.0)]
        val position=RealArray.array(3,0.0)
        val sums=RealArray.array(27,0.0)
        fun consume()=
          let fun value i=if i<6 then RealArray.sub(Array.sub(pv,i div 3),i mod 3)
                else RealArray.sub(position,i-6)
              fun loop i=if i=9 then()else
                let val v=value i
                    val _=if Real.isFinite v then()else raise Fail "incorrect result: nonfinite almabench state"
                    val _=RealArray.update(sums,i,RealArray.sub(sums,i)+v)
                    val _=RealArray.update(sums,9+i,RealArray.sub(sums,9+i)+Real.abs v)
                    val _=RealArray.update(sums,18+i,RealArray.sub(sums,18+i)+v*v)
                in loop(i+1)end
          in loop 0 end
        fun planets p=if p>7 then()else
          (BenchAlma.planetPV jd p pv;BenchAlma.raDecDist pv position;consume();planets(p+1))
        val _=planets 0
        fun day n=if n>=days then()else
          (RealArray.update(jd,0,RealArray.sub(jd,0)+1.0);planets 0;day(n+1))
        fun repeat n=if n>=loops then()else
          (RealArray.update(jd,0,BenchAlmaTables.j2000);RealArray.update(jd,1,0.0);
           day 0;repeat(n+1))
        val _=repeat 0
        val actual=List.tabulate(27,fn i=>RealArray.sub(sums,i))
    in if valid(actual,wanted)then Int.toString(8+loops*days*8)^":27"
       else raise Fail "incorrect result: almabench aggregate moments"end
    |run _=raise Fail "almabench expects repetitions, days and numerical reference"
end
