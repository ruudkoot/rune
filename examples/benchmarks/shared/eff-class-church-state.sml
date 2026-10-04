(* CSD retains its three typeclass operations as a ground State dictionary. *)
structure BenchClassChurchState =
struct
  type runner = int -> unit * int
  type dictionary = {pure : unit -> runner, get : (int -> runner) -> runner,
                     put : int -> runner -> runner}
  val stateDictionary : dictionary =
    {pure=fn result => fn state => (result,state),
     get=fn got => fn state => got state state,
     put=fn replacement => fn continuation => fn _ => continuation replacement}
  fun times (dictionary : dictionary) 0 = #pure dictionary ()
    | times dictionary n = #get dictionary (fn state =>
        let val state' = state+1
        in #put dictionary state' (times dictionary (n-1)) end)
  fun run n = times stateDictionary n 0
end
