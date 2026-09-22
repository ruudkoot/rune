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
  type array = elem RuneArray2.array
  type region = {base : array, row : int, col : int, nrows : int option, ncols : int option}
  datatype traversal = datatype Array2.traversal
  (* the sealed Array2 has a traversal of its own: these are the same two *)
  fun inner Array2.RowMajor = RuneArray2.RowMajor
    | inner Array2.ColMajor = RuneArray2.ColMajor

  val array : int * int * elem -> array = RuneArray2.array
  val fromList : elem list list -> array = RuneArray2.fromList
  fun tabulate trv arg : array = RuneArray2.tabulate (inner trv) arg
  val sub : array * int * int -> elem = RuneArray2.sub
  val update : array * int * int * elem -> unit = RuneArray2.update
  val dimensions : array -> int * int = RuneArray2.dimensions
  val nCols : array -> int = RuneArray2.nCols
  val nRows : array -> int = RuneArray2.nRows

  (* "It raises Subscript if i < 0 or nRows arr <= i", and the same for j and
     nCols arr *)
  fun row (arr : array, i) =
    if i < 0 orelse i >= nRows arr then raise Subscript
    else V.tabulate (nCols arr, fn j => sub (arr, i, j))
  fun column (arr : array, j) =
    if j < 0 orelse j >= nCols arr then raise Subscript
    else V.tabulate (nRows arr, fn i => sub (arr, i, j))

  val copy : {src : region, dst : array, dst_row : int, dst_col : int} -> unit = RuneArray2.copy
  fun appi trv f (reg : region) = RuneArray2.appi (inner trv) f reg
  fun app trv f (arr : array) = RuneArray2.app (inner trv) f arr
  fun foldi trv f init (reg : region) = RuneArray2.foldi (inner trv) f init reg
  fun fold trv f init (arr : array) = RuneArray2.fold (inner trv) f init arr
  fun modifyi trv f (reg : region) = RuneArray2.modifyi (inner trv) f reg
  fun modify trv f (arr : array) = RuneArray2.modify (inner trv) f arr
end
