(* Pending request ids and their ownership, independent of transports.

   Implements: LSP_REQUESTS *)
structure LspRequests :> LSP_REQUESTS =
struct
  datatype 'a t = Table of {prefix : string, limit : int, next : IntInf.int ref,
                           pending : (JsonRpc.id * 'a) list ref}
  exception Full
  fun new {prefix, maxPending} =
    if maxPending <= 0 orelse not (Utf8.isValid prefix) then raise Domain
    else Table {prefix = prefix, limit = maxPending, next = ref (IntInf.fromInt 0), pending = ref []}
  fun size (Table {pending, ...}) = length (!pending)
  fun reserve (Table {limit, pending, ...}, id, data) =
    let val _ = LspProtocol.idToJson id
    in if List.exists (fn (key, _) => key = id) (!pending) then false
       else if length (!pending) >= limit then raise Full
       else (pending := (id, data) :: !pending; true) end
  fun issue (table as Table {prefix, next, pending, ...}, {method, params, data}) =
    let val () = case table of Table {limit, ...} => if length (!pending) >= limit then raise Full else ()
        fun fresh n =
          let val id = JsonRpc.String (prefix ^ IntInf.toString n)
          in if List.exists (fn (key, _) => key = id) (!pending) then fresh (IntInf.+ (n, 1)) else (id, n) end
        val (id, n) = fresh (!next)
        val message = JsonRpc.Request {id = id, method = method, params = params}
        val _ = LspProtocol.encode message
        val _ = reserve (table, id, data)
        val () = next := IntInf.+ (n, 1)
    in message end
  fun take (Table {pending, ...}, id) =
    let fun find [] = NONE
          | find ((key, data) :: rest) = if key = id then SOME data else find rest
        val found = find (!pending)
        val () = case found of NONE => () | SOME _ => pending := List.filter (fn (key, _) => key <> id) (!pending)
    in found end
  fun resolve (table, JsonRpc.Response {id = SOME id, outcome}) = Option.map (fn data => (data, outcome)) (take (table, id))
    | resolve _ = NONE
  fun cancel (table, id) = Option.map (fn data => (JsonRpc.cancel id, data)) (take (table, id))
  fun clear (Table {pending, ...}) = let val entries = !pending in pending := []; List.map #2 entries end
end
