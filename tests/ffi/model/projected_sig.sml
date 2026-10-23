(* Compile-only projection golden and type-sharing witnesses. These
   structures do not implement foreign calls. *)
signature FFI_MODEL_GOLDEN =
sig
  eqtype memory
  val copyString : string -> string
  val fetch : unit -> {answer : Int32.int}
  val alias : memory -> memory
end
structure ProjectionTypes = struct datatype memory = Memory of int ref end
structure ProjectionNative : FFI_MODEL_GOLDEN where type memory = ProjectionTypes.memory =
struct
  type memory = ProjectionTypes.memory
  fun copyString text = text
  fun fetch () = {answer=Int32.fromInt 42}
  fun alias memory = memory
end
structure ProjectionSdl : FFI_MODEL_GOLDEN where type memory = ProjectionTypes.memory = ProjectionNative
structure ProjectionMock : FFI_MODEL_GOLDEN where type memory = ProjectionTypes.memory = ProjectionNative
functor ProjectionSharing (X : sig
  structure Native : FFI_MODEL_GOLDEN
  structure Sdl : FFI_MODEL_GOLDEN
  structure Mock : FFI_MODEL_GOLDEN
  sharing type Native.memory = Sdl.memory = Mock.memory
end) =
struct
  fun transfer memory = X.Mock.alias(X.Sdl.alias(X.Native.alias memory))
end
structure ProjectionWitness = ProjectionSharing(struct
  structure Native=ProjectionNative
  structure Sdl=ProjectionSdl
  structure Mock=ProjectionMock
end)
