(* A table from keys to values, as the program uses it: the result's
   signature. Its key is the parameter's (TABLE where type key = K.t), and
   its table and exception are new at each application. *)
signature TABLE =
sig
  type key
  type 'a table
  exception Missing of key
  val empty : 'a table
  val insert : 'a table * key * 'a -> 'a table
  val find : 'a table * key -> 'a option
  val get : 'a table * key -> 'a
  val size : 'a table -> int
  (* the entries, by their keys in order *)
  val toList : 'a table -> (key * 'a) list
end
