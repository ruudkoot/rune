(* Explicit call-by-need, including memoized exceptions and re-entry checks. *)
structure BenchLazy =
struct
  datatype 'a state = Pending of unit -> 'a | Evaluating | Value of 'a | Failed of exn
  type 'a delay = 'a state ref
  fun delay f = ref (Pending f)
  fun force cell =
    case !cell of
      Value x => x
    | Failed e => raise e
    | Evaluating => raise Fail "recursive forcing of delay"
    | Pending f =>
        (cell := Evaluating;
         let val value = f () handle e => (cell := Failed e; raise e)
         in cell := Value value; value end)
end
