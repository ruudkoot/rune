(* What system/Basis/Implementation/array2.sml takes of SML/NJ's compiler,
   from outside the Basis Library, so that the file compiles as a program
   and replaces Array2 for what follows:
     use "stand-in.sml"; use "array2.sml"; use "bug.sml"; *)
structure InlineT =
struct
  structure Int = struct fun ltu (a : int, b : int) = Word.< (Word.fromInt a, Word.fromInt b) end
  structure PolyArray =
  struct
    val array = Array.array
    val sub = Unsafe.Array.sub
    val update = Unsafe.Array.update
    fun newArray0 () = Array.fromList []
  end
end
structure Core = struct val max_length = Array.maxLen end
