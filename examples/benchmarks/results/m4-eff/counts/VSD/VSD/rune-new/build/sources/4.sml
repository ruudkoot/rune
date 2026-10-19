(* VSD keeps its get/put class dictionary over the shared strict-tuple State. *)
structure BenchClassVanState =
struct
  structure S = BenchStockState
  structure L = BenchLazy
  type dictionary = {get : S.counter S.state, put : S.counter -> unit S.state}
  val stateDictionary : dictionary = {get=S.get,put=S.put}
  fun modify (operations : dictionary) f =
    S.bind (#get operations)(fn state =>
      let val state' = f(L.force state)
      in #put operations (S.value state') end)
  fun run n = S.times n (modify stateDictionary (fn state => state+1))(S.value 0)
end
