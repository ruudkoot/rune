(* The functor behind the monomorphic two-dimensional arrays (MONO_ARRAY2):
   an array of V.elem is an Array2.array of them, and a row or a column is
   made into a V.vector. "If an implementation provides any structure
   matching MONO_ARRAY2, it must also supply the structure Array2 and its
   signature ARRAY2", and the traversal is that of Array2. The signature
   MONO_ARRAY2 is loaded after this file (it is generated with the others of
   the specification), so the instances are not sealed with it; they match
   it, as tests/basis checks. *)
functor RuneMonoArray2Fn (structure V : MONO_VECTOR) =
struct
  type elem = V.elem
  type vector = V.vector
  (* equality is that of Array2.array: identity *)
  type array = elem Array2.array
  type region = {base : array, row : int, col : int, nrows : int option, ncols : int option}
  datatype traversal = datatype Array2.traversal

  val array : int * int * elem -> array = Array2.array
  val fromList : elem list list -> array = Array2.fromList
  val tabulate : traversal -> int * int * (int * int -> elem) -> array = Array2.tabulate
  val sub : array * int * int -> elem = Array2.sub
  val update : array * int * int * elem -> unit = Array2.update
  val dimensions : array -> int * int = Array2.dimensions
  val nCols : array -> int = Array2.nCols
  val nRows : array -> int = Array2.nRows

  (* "It raises Subscript if i < 0 or nRows arr <= i", and the same for j and
     nCols arr *)
  fun row (arr : array, i) =
    if i < 0 orelse i >= nRows arr then raise Subscript
    else V.tabulate (nCols arr, fn j => sub (arr, i, j))
  fun column (arr : array, j) =
    if j < 0 orelse j >= nCols arr then raise Subscript
    else V.tabulate (nRows arr, fn i => sub (arr, i, j))

  val copy : {src : region, dst : array, dst_row : int, dst_col : int} -> unit = Array2.copy
  val appi : traversal -> (int * int * elem -> unit) -> region -> unit = Array2.appi
  val app : traversal -> (elem -> unit) -> array -> unit = Array2.app
  fun foldi trv f init (reg : region) = Array2.foldi trv f init reg
  fun fold trv f init (arr : array) = Array2.fold trv f init arr
  val modifyi : traversal -> (int * int * elem -> elem) -> region -> unit = Array2.modifyi
  val modify : traversal -> (elem -> elem) -> array -> unit = Array2.modify
end
