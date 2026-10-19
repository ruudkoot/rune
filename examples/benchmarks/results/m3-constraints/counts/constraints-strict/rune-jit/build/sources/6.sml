structure Benchmark =
struct
  structure K = BenchConstraintsFn(BenchStrict)
  val name = "constraints-strict"
  fun reference path =
    let val input = TextIO.openIn path
        val text = TextIO.inputAll input
        val _ = TextIO.closeIn input
    in List.map(fn line => List.map BenchInput.integer (String.tokens Char.isSpace line))
         (String.tokens(fn c => c= #"\n")text)end
  fun run [size,repetitions,path] =
    let val n = BenchInput.between(1,8)(BenchInput.integer size)
        val repeats = BenchInput.between(1,240)(BenchInput.integer repetitions)
        val expected = reference path
        val methods = [K.bt,K.bm,K.bjbt,K.bjbt',K.fc]
        fun run method =
          let val solutions = K.Q.toList(K.search method (K.queens n))
              val actual = List.map(fn state => List.map(fn (_,candidate) => candidate)(List.rev state))solutions
              val _ = if actual=expected then () else raise Fail "constraint solution order differs"
          in List.length solutions end
        fun loop 0 totals = String.concatWith ","(List.map Int.toString totals)
          | loop left totals =
              let val counts = List.map run methods
              in loop(left-1)(ListPair.mapEq op + (totals,counts))end
    in loop repeats [0,0,0,0,0]end
    | run _ = raise Fail "constraints expects size repetitions reference"
end
