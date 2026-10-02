(* shims for the 1997 Basis forms fxp was written against: Timer.checkCPUTimer
   with a gc field, and the vector and array iterators over (v, i, len option) *)
structure Timer = struct
  open Timer
  fun checkCPUTimer t = let val {usr, sys} = Timer.checkCPUTimer t in {usr = usr, sys = sys, gc = Timer.checkGCTime t} end
end
structure Substring = struct open Substring val all = full end
structure Vector = struct
  open Vector
  fun foldli f b (v, i, no) = VectorSlice.foldli (fn (j,x,a)=>f(i+j,x,a)) b (VectorSlice.slice (v, i, no))
  fun foldri f b (v, i, no) = VectorSlice.foldri (fn (j,x,a)=>f(i+j,x,a)) b (VectorSlice.slice (v, i, no))
  fun appi f (v, i, no) = VectorSlice.appi (fn (j,x)=>f(i+j,x)) (VectorSlice.slice (v, i, no))
  fun mapi f (v, i, no) = VectorSlice.mapi (fn (j,x)=>f(i+j,x)) (VectorSlice.slice (v, i, no))
  fun extract (v, i, no) = VectorSlice.vector (VectorSlice.slice (v, i, no))
end
structure Array = struct
  open Array
  fun appi f (a, i, no) = ArraySlice.appi (fn (j,x)=>f(i+j,x)) (ArraySlice.slice (a, i, no))
  fun foldli f b (a, i, no) = ArraySlice.foldli (fn (j,x,a)=>f(i+j,x,a)) b (ArraySlice.slice (a, i, no))
  fun foldri f b (a, i, no) = ArraySlice.foldri (fn (j,x,a)=>f(i+j,x,a)) b (ArraySlice.slice (a, i, no))
  fun modifyi f (a, i, no) = ArraySlice.modifyi (fn (j,x)=>f(i+j,x)) (ArraySlice.slice (a, i, no))
  fun extract (a, i, no) = ArraySlice.vector (ArraySlice.slice (a, i, no))
end
