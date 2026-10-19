structure Benchmark =
struct
  val name="nbody-sandmark"
  fun bound text=case Real.fromString text of SOME r=>
      if Real.isFinite r andalso r>=0.0 then r else raise Fail "invalid nbody error bound"
    | NONE=>raise Fail "invalid nbody error bound"
  fun run [steps,path,absolute,relative]=
    let val n=BenchInput.between(0,50000000)(BenchInput.integer steps)
        val _=BenchRecordNBodyCheck.run n path(bound absolute)(bound relative)
    in Int.toString n^":37:checked"end
    | run _=raise Fail "nbody expects steps reference absolute-bound relative-bound"
end
