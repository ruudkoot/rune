(* FS retains free constructors, suspended continuations, bind and interpreter. *)
structure BenchFreeState =
struct
  structure L = BenchLazy
  datatype node = Pure | Get of int -> node L.delay | Put of int * node L.delay
  type action = node L.delay
  fun pure () = L.delay(fn () => Pure)
  fun bind action next = L.delay(fn () => case L.force action of
      Pure => L.force(next())
    | Get get => Get(fn state => bind (get state)next)
    | Put(state,continuation) => Put(state,bind continuation next))
  fun modify f = L.delay(fn () => Get(fn state => L.delay(fn () => Put(f state,pure()))))
  fun times 0 _ = pure ()
    | times n action = bind action (fn _ => times(n-1)action)
  fun runState action state = case L.force action of
      Pure => ((),state)
    | Get get => runState(get state)state
    | Put(replacement,continuation) => runState continuation replacement
  fun run n = runState(times n (modify(fn state => state+1)))0
end
