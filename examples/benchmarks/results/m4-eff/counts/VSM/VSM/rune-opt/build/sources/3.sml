(* Used State operations: (c) Andy Gill 2001 and Oregon Graduate Institute
   of Science and Technology, 2001. BSD-style notices are retained in
   S/upstream/library/MTL-LICENSE and TRANSFORMERS-LICENSE. *)
(* Strict State's tuple is demanded by bind; its state field remains lazy. *)
structure BenchStockState =
struct
  structure L = BenchLazy
  type counter = int L.delay
  type 'a state = counter -> 'a * counter
  fun value n = ref(L.Value n)
  fun pure result state = (result,state)
  fun bind action next state =
    let val (result,state') = action state
    in next result state' end
  fun modify f state = ((),L.delay(fn () => f(L.force state)))
  fun get state = (state,state)
  fun put replacement _ = ((),replacement)
  fun times 0 _ = pure ()
    | times n action = bind action (fn _ => times(n-1)action)
  fun run n = times n (modify(fn s => s+1))(value 0)
end
