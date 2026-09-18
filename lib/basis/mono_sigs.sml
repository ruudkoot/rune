(* The signatures of the monomorphic vectors, arrays and their slices. *)
signature MONO_VECTOR =
sig
  type vector
  type elem
  val maxLen : int
  val fromList : elem list -> vector
  val tabulate : int * (int -> elem) -> vector
  val length : vector -> int
  val sub : vector * int -> elem
  val update : vector * int * elem -> vector
  val concat : vector list -> vector
  val appi : (int * elem -> unit) -> vector -> unit
  val app : (elem -> unit) -> vector -> unit
  val mapi : (int * elem -> elem) -> vector -> vector
  val map : (elem -> elem) -> vector -> vector
  val foldli : (int * elem * 'b -> 'b) -> 'b -> vector -> 'b
  val foldri : (int * elem * 'b -> 'b) -> 'b -> vector -> 'b
  val foldl : (elem * 'b -> 'b) -> 'b -> vector -> 'b
  val foldr : (elem * 'b -> 'b) -> 'b -> vector -> 'b
  val findi : (int * elem -> bool) -> vector -> (int * elem) option
  val find : (elem -> bool) -> vector -> elem option
  val exists : (elem -> bool) -> vector -> bool
  val all : (elem -> bool) -> vector -> bool
  val collate : (elem * elem -> order) -> vector * vector -> order
end

signature MONO_ARRAY =
sig
  eqtype array
  type elem
  type vector
  val maxLen : int
  val array : int * elem -> array
  val fromList : elem list -> array
  val tabulate : int * (int -> elem) -> array
  val length : array -> int
  val sub : array * int -> elem
  val update : array * int * elem -> unit
  val vector : array -> vector
  val copy : {src : array, dst : array, di : int} -> unit
  val copyVec : {src : vector, dst : array, di : int} -> unit
  val appi : (int * elem -> unit) -> array -> unit
  val app : (elem -> unit) -> array -> unit
  val modifyi : (int * elem -> elem) -> array -> unit
  val modify : (elem -> elem) -> array -> unit
  val foldli : (int * elem * 'b -> 'b) -> 'b -> array -> 'b
  val foldri : (int * elem * 'b -> 'b) -> 'b -> array -> 'b
  val foldl : (elem * 'b -> 'b) -> 'b -> array -> 'b
  val foldr : (elem * 'b -> 'b) -> 'b -> array -> 'b
  val findi : (int * elem -> bool) -> array -> (int * elem) option
  val find : (elem -> bool) -> array -> elem option
  val exists : (elem -> bool) -> array -> bool
  val all : (elem -> bool) -> array -> bool
  val collate : (elem * elem -> order) -> array * array -> order
end

signature MONO_VECTOR_SLICE =
sig
  type elem
  type vector
  type slice
  val length : slice -> int
  val sub : slice * int -> elem
  val full : vector -> slice
  val slice : vector * int * int option -> slice
  val subslice : slice * int * int option -> slice
  val base : slice -> vector * int * int
  val vector : slice -> vector
  val concat : slice list -> vector
  val isEmpty : slice -> bool
  val getItem : slice -> (elem * slice) option
  val appi : (int * elem -> unit) -> slice -> unit
  val app : (elem -> unit) -> slice -> unit
  val mapi : (int * elem -> elem) -> slice -> vector
  val map : (elem -> elem) -> slice -> vector
  val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
  val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
  val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b
  val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b
  val findi : (int * elem -> bool) -> slice -> (int * elem) option
  val find : (elem -> bool) -> slice -> elem option
  val exists : (elem -> bool) -> slice -> bool
  val all : (elem -> bool) -> slice -> bool
  val collate : (elem * elem -> order) -> slice * slice -> order
end

signature MONO_ARRAY_SLICE =
sig
  type elem
  type array
  type slice
  type vector
  type vector_slice
  val length : slice -> int
  val sub : slice * int -> elem
  val update : slice * int * elem -> unit
  val full : array -> slice
  val slice : array * int * int option -> slice
  val subslice : slice * int * int option -> slice
  val base : slice -> array * int * int
  val vector : slice -> vector
  val copy : {src : slice, dst : array, di : int} -> unit
  val copyVec : {src : vector_slice, dst : array, di : int} -> unit
  val isEmpty : slice -> bool
  val getItem : slice -> (elem * slice) option
  val appi : (int * elem -> unit) -> slice -> unit
  val app : (elem -> unit) -> slice -> unit
  val modifyi : (int * elem -> elem) -> slice -> unit
  val modify : (elem -> elem) -> slice -> unit
  val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
  val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
  val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b
  val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b
  val findi : (int * elem -> bool) -> slice -> (int * elem) option
  val find : (elem -> bool) -> slice -> elem option
  val exists : (elem -> bool) -> slice -> bool
  val all : (elem -> bool) -> slice -> bool
  val collate : (elem * elem -> order) -> slice * slice -> order
end
