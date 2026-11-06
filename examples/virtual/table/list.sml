(* The first implementation of Table: an association list, kept in the
   order of its keys, each key once. *)
_export functor Table (K : KEY) : TABLE where type key = K.t =
struct
  type key = K.t
  type 'a table = (key * 'a) list
  exception Missing of key
  val empty = []
  fun insert ([], k, v) = [(k, v)]
    | insert (t as (k', v') :: rest, k, v) =
        case K.compare (k, k') of
          LESS => (k, v) :: t
        | EQUAL => (k, v) :: rest
        | GREATER => (k', v') :: insert (rest, k, v)
  fun find ([], _) = NONE
    | find ((k', v) :: rest, k) =
        case K.compare (k, k') of
          LESS => NONE
        | EQUAL => SOME v
        | GREATER => find (rest, k)
  fun get (t, k) = case find (t, k) of SOME v => v | NONE => raise Missing k
  val size = List.length
  fun toList t = t
end
