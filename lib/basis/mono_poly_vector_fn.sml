(* One of the functors behind the monomorphic vectors, arrays and slices. Each
   is in a file of its own, and so is each family of instances, because a
   program pays for what it loads: BinIO needs Word8Vector and nothing else. *)
(* A vector of any element type but characters and bytes is a polymorphic
   vector, so the members are those of Vector. MONO_VECTOR says `type vector`,
   not `eqtype`: the elements need not admit equality (RealVector). *)
functor RuneMonoVectorFn (type elem) =
struct
  type elem = elem
  type vector = elem Vector.vector
  val maxLen = Vector.maxLen
  val fromList : elem list -> vector = Vector.fromList
  val tabulate : int * (int -> elem) -> vector = Vector.tabulate
  val length : vector -> int = Vector.length
  val sub : vector * int -> elem = Vector.sub
  val update : vector * int * elem -> vector = Vector.update
  val concat : vector list -> vector = Vector.concat
  val appi : (int * elem -> unit) -> vector -> unit = Vector.appi
  val app : (elem -> unit) -> vector -> unit = Vector.app
  val mapi : (int * elem -> elem) -> vector -> vector = Vector.mapi
  val map : (elem -> elem) -> vector -> vector = Vector.map
  fun foldli f init (v : vector) = Vector.foldli f init v
  fun foldri f init (v : vector) = Vector.foldri f init v
  fun foldl f init (v : vector) = Vector.foldl f init v
  fun foldr f init (v : vector) = Vector.foldr f init v
  val findi : (int * elem -> bool) -> vector -> (int * elem) option = Vector.findi
  val find : (elem -> bool) -> vector -> elem option = Vector.find
  val exists : (elem -> bool) -> vector -> bool = Vector.exists
  val all : (elem -> bool) -> vector -> bool = Vector.all
  val collate : (elem * elem -> order) -> vector * vector -> order = Vector.collate
end
