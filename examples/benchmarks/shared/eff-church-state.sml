(* Ground specialization of CS's Church handler result to the used State. *)
structure BenchChurchState =
struct
  type result = unit * int
  type runner = int -> result
  type church = (unit -> runner) -> ((int -> runner) -> runner) -> (int -> runner -> runner) -> runner
  fun pure result finish _ _ = finish result
  fun bind action next finish get put =
    action (fn result => next result finish get put) get put
  fun modify f finish get put =
    get(fn state => let val state' = f state in put state' (finish ()) end)
  fun times 0 _ = pure ()
    | times n action = bind action (fn _ => times(n-1)action)
  fun runState action state =
    action (fn result => fn state => (result,state))
      (fn got => fn state => got state state)
      (fn replacement => fn continuation => fn _ => continuation replacement) state
  fun run n = runState(times n (modify(fn s => s+1)))0
end
