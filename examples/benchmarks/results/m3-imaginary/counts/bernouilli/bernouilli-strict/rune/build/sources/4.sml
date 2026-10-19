structure BenchBernoulliCheck =
struct
  fun run calculate [size,reps,reference] =
    let val n=BenchInput.between(0,320)(BenchInput.integer size)
        val r=BenchInput.between(1,500)(BenchInput.integer reps)
        val _=if List.exists(fn p=>p=reference)["expected/smoke.txt","expected/normal.txt","expected/large.txt"]then()else raise Fail "Bernoulli reference path"
        val f=TextIO.openIn reference
        val fields=String.tokens Char.isSpace(TextIO.inputAll f)
        val _=TextIO.closeIn f
        val (expected,wantHash)=case List.map IntInf.fromString fields of
          [SOME a,SOME b,SOME h]=>((a,b),h)|_=>raise Fail "Bernoulli reference"
        fun one()=let val got=calculate n
          val actualHash=Word64.toLargeIntX(BenchNofibHash.hash(BenchRational.show got))
          in if got=expected andalso actualHash=wantHash then n
          else raise Fail "Bernoulli rational or Show hash differs"end
    in IntInf.toString(BenchInput.repeat r one)end
    |run _ _=raise Fail "bernouilli expects index repetitions reference"
end
