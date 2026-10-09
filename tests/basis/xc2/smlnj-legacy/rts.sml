(* The structure Assembly that SML/NJ's runtime system gives its library
   (assembly.sig), made of Rune's. It is not ascribed ASSEMBLY: that has a
   polymorphic value vector0, which SML cannot make of an application, and
   rewrite.awk makes the library's uses of it XC2N.vector0 (). A string is
   Rune's and made whole: create_s, which SML/NJ fills in place, raises, and
   the patch makes the strings otherwise. *)
structure Assembly =
struct
  type object = PrimTypes.object
  datatype option = datatype option

  structure A =
  struct
    type c_function = PrimTypes.c_function
    type word8array = PrimTypes.word8array
    type real64array = PrimTypes.real64array
    type spin_lock = PrimTypes.spin_lock
    fun array (n, x) = Array.array (n, x)
    fun bind_cfun (lib, name) = PrimTypes.XC2NCFunction (lib, name)
    (* the C functions are named directly (rewrite.awk) *)
    fun callc (PrimTypes.XC2NCFunction (lib, name), _) = XC2.unimplemented ("C function " ^ lib ^ " " ^ name)
    fun create_b n : word8array = Array.array (n, 0w0)
    fun create_r n : real64array = Array.array (n, 0.0)
    fun create_s (_ : int) : string = XC2.unimplemented "Assembly.A.create_s: a string written in place"
    fun create_v (_ : int, l) = Vector.fromList l
    val floor = Real.floor
    fun logb x = if Real.== (x, 0.0) then ~1023 else #exp (Real.toManExp x) - 1
    fun scalb (x, n) = Real.fromManExp {man = x, exp = n}
    fun try_lock (PrimTypes.XC2NSpinLock r) = if !r then false else (r := true; true)
    fun unlock (PrimTypes.XC2NSpinLock r) = r := false
  end

  exception Div = Div
  exception Overflow = Overflow
  exception SysErr = XC2N.SysErr

  val profCurrent = ref 0
  val pollEvent = ref false
  val pollFreq = ref 0
  val pollHandler : (unit PrimTypes.cont -> unit PrimTypes.cont) ref = ref (fn k => k)
  val activeProcs = ref 1
  val pstruct = ref PrimTypes.XC2NObject
  val sighandler : ((int * int * unit PrimTypes.cont) -> unit PrimTypes.cont) ref = ref (fn (_, _, k) => k)
end
