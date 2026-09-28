(* What the shims of the xc2 configurations share (tests/basis/xc2/README.md):
   compiled after Rune's library and before a host's prologue and shim. *)
structure XC2 =
struct
  exception Unimplemented of string
  fun unimplemented what = raise Unimplemented what

  (* An array of a host's. MLton and MLKit allocate an array before they have
     an element to fill it with, and Rune cannot: the cells are made at the
     first update, and until then only the length is known. A ref, so that
     every array admits equality, as Rune's arrays do. *)
  datatype 'a cells = Cells of 'a Array.array | Uninit of int
  type 'a array = 'a cells ref

  structure Array =
  struct
    fun alloc n : 'a array = ref (Uninit n)
    fun length (ref (Cells a) : 'a array) = Array.length a
      | length (ref (Uninit n)) = n
    fun sub (ref (Cells a) : 'a array, i) = Array.sub (a, i)
      | sub (ref (Uninit _), _) = raise Fail "xc2: an element of an array read before any is written"
    fun update (r as ref (Uninit n) : 'a array, i, x) =
          if i < 0 orelse i >= n then raise Subscript else r := Cells (Array.array (n, x))
      | update (ref (Cells a), i, x) = Array.update (a, i, x)
    fun toVector (ref (Cells a) : 'a array) = Array.vector a
      | toVector (ref (Uninit 0)) = Vector.fromList []
      | toVector (ref (Uninit _)) = raise Fail "xc2: a vector of an array never written"
  end

end

(* A host's string types, Rune's string and WideString.string, where the host
   takes them for vectors (MLton) or tables (MLKit) of their characters *)
functor XC2StringOps (type char
                      eqtype string
                      val size : string -> int
                      val sub : string * int -> char
                      val tabulate : int * (int -> char) -> string) =
struct
  val length = size
  val subUnsafe = sub
  fun fromVector (v : char vector) : string =
    tabulate (Vector.length v, fn i => Vector.sub (v, i))
  fun toVector (s : string) : char vector =
    Vector.tabulate (size s, fn i => sub (s, i))
  fun fromArray (a : char XC2.array) : string =
    tabulate (XC2.Array.length a, fn i => XC2.Array.sub (a, i))
  (* copyUnsafe (dst, di, src, si, len): src[si, si + len) to dst[di, ...) *)
  fun copyUnsafe (dst : char XC2.array, di, src : string, si, len) =
    let fun loop k = if k >= len then () else (XC2.Array.update (dst, di + k, sub (src, si + k)); loop (k + 1))
    in loop 0 end
end
structure XC2String8 = XC2StringOps (type char = char type string = string
                                     val size = String.size val sub = String.sub
                                     val tabulate = CharVector.tabulate)
structure XC2String32 = XC2StringOps (type char = WideChar.char type string = WideString.string
                                      val size = WideString.size val sub = WideString.sub
                                      val tabulate = WideCharVector.tabulate)

(* The exceptions of Rune's that a host's library takes for its own: those
   Rune's machine raises (Overflow, Div, Subscript, Size, Bind and Match are
   the compiler's anyway) and those the shims' use of Rune's library can. *)
structure XC2RuneExn =
struct
  exception Chr = Chr
  exception Div = Div
  exception Domain = Domain
  exception Fail = Fail
  exception Overflow = Overflow
  exception Size = Size
  exception Span = Span
  exception Subscript = Subscript
end
