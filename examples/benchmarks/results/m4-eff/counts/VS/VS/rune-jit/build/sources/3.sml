(* VS specializes the used unit/int monadic types and retains strict S binds. *)
structure BenchVanState =
struct
  type 'a state = int -> 'a * int
  type handlers =
    {pure : unit -> unit state,
     bindUnit : unit state -> (unit -> unit state) -> unit state,
     bindInt : int state -> (int -> unit state) -> unit state,
     get : int state, put : int -> unit state}
  type encoded = handlers -> unit state
  fun statePure result state = (result,state)
  fun stateBind action next state =
    let val (result,state') = action state
        val (result',state'') = next result state'
    in (result',state'') end
  val handlers : handlers = {pure=statePure,bindUnit=stateBind,bindInt=stateBind,
    get=fn state => (state,state),put=fn replacement => fn _ => ((),replacement)}
  fun pure result (operations : handlers) = #pure operations result
  fun bind action next (operations : handlers) =
    #bindUnit operations (action operations)(fn result => next result operations)
  fun modify f (operations : handlers) =
    #bindInt operations (#get operations)(fn state =>
      let val state' = f state in #put operations state' end)
  fun times 0 _ = pure ()
    | times n action = bind action (fn _ => times(n-1)action)
  fun run n = times n (modify(fn state => state+1))handlers 0
end
