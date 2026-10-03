(* Preserve the actual CPS pipeline and mutable fold_2.
   The used state is int, payload is a portable exact integer, and unfold's
   continuation result is bool; unused existential/rank-polymorphic cases
   in the OCaml interface are not prerequisites of this concrete workload. *)
structure Benchmark =
struct
  val name = "sequence_cps"
  type unfold = int -> bool -> (int -> bool) -> (int -> IntInf.int -> bool) -> bool
  datatype sequence = Sequence of int * {unfold : unfold}
  fun map (Sequence(state,{unfold})) f =
    Sequence(state,{unfold=fn state => fn done => fn skip => fn yield =>
      unfold state done skip (fn next => fn value => yield next (f value))})
  fun filter (Sequence(state,{unfold})) f =
    Sequence(state,{unfold=fn state => fn done => fn skip => fn yield =>
      unfold state done skip (fn next => fn value =>
        if f value then yield next value else skip next)})
  fun fold (Sequence(state,{unfold})) initial f =
    let
      val current = ref state
      val value = ref initial
      fun skip next = (current := next;true)
      fun yield next item = (current := next;value := f(!value,item);true)
      val _ = while unfold (!current) false skip yield do ()
    in !value end
  fun test n =
    let
      val sequence = Sequence(0,{unfold=fn i => fn done => fn _ => fn yield =>
        if i>=n then done else yield (i+1) (IntInf.fromInt i)})
      val added = map sequence (fn value => IntInf.+(value,3))
      val selected = filter added (fn value => IntInf.andb(value,1)=0)
      val squared = map selected (fn value => IntInf.*(value,value))
    in fold squared 0 IntInf.+ end
  fun run [size] =
    let
      val n = BenchInput.between (0,10000) (BenchInput.integer size)
      val result = ref (IntInf.fromInt 0)
      fun loop i = if i>n then () else
        (result := IntInf.+(!result,test i);loop(i+1))
      val _ = loop 0
    in IntInf.toString(!result) end
    | run _ = raise Fail "sequence_cps expects outer iteration bound"
end
