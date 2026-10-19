(* VSM retains its get/put abstraction and State monad bind layer. *)
structure BenchVanMtlState =
struct
  structure S = BenchStockState
  structure L = BenchLazy
  type encoded = S.counter S.state -> (S.counter -> unit S.state) -> unit S.state
  fun pure result _ _ = S.pure result
  fun bind action next get put =
    S.bind (action get put)(fn result => next result get put)
  fun modify f get put = S.bind get (fn state =>
    let val state' = f(L.force state) in put(S.value state') end)
  fun times 0 _ = pure ()
    | times n action = bind action (fn _ => times(n-1)action)
  fun run n = times n (modify(fn state => state+1)) S.get S.put (S.value 0)
end
