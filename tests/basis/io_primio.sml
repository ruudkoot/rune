(* requires: TextPrimIO BinPrimIO CharVector CharArray CharVectorSlice CharArraySlice Word8 Word8Vector Word8Array Word8VectorSlice Word8ArraySlice Position IO *)
(* uses: spec-sigs/PRIM_IO.sml fn/prim_io_fn.sml *)
(* TextPrimIO and BinPrimIO (signature PRIM_IO). Expected values follow
   https://smlfamily.github.io/Basis/prim-io.html. The checks that hold for
   both are in fn/prim_io_fn.sml; they need the slices of the instances to
   be those of CharVectorSlice, CharArraySlice, Word8VectorSlice and
   Word8ArraySlice (io_primio_sig.sml). Bytes are written there as the
   characters of the same code.

   compare needs positions: BinPrimIO.pos is Position.int, and the positions
   of a file are byte offsets, "some underlying linear ordering on pos
   values"; TextPrimIO.pos is abstract, and textio_streamio.sml compares the
   positions of a file. *)
structure TestIOPrimIO =
struct
  fun id (s : string) = s
  fun bytes (s : string) : Word8Vector.vector = Word8Vector.tabulate (String.size s, fn i => Word8.fromInt (Char.ord (String.sub (s, i))))
  fun chars (v : Word8Vector.vector) : string = CharVector.tabulate (Word8Vector.length v, fn i => Char.chr (Word8.toInt (Word8Vector.sub (v, i))))

  structure Text = TestPrimIOFn (structure P = TextPrimIO val name = "TextPrimIO" val fromString = id val toString = id val sliceVector = CharVectorSlice.vector val vectorSlice = CharVectorSlice.slice val newArray = fn s => CharArray.fromList (String.explode s) val arrayString = CharArray.vector val arraySlice = CharArraySlice.slice val arraySliceLength = CharArraySlice.length val arraySliceVector = CharArraySlice.vector val copyIntoSlice = fn (v, sl) => let val (a, i, _) = CharArraySlice.base sl in CharArray.copyVec {src = v, dst = a, di = i} end)
  structure Bin = TestPrimIOFn (structure P = BinPrimIO val name = "BinPrimIO" val fromString = bytes val toString = chars val sliceVector = Word8VectorSlice.vector val vectorSlice = Word8VectorSlice.slice val newArray = fn s => Word8Array.tabulate (String.size s, fn i => Word8.fromInt (Char.ord (String.sub (s, i)))) val arrayString = fn a => chars (Word8Array.vector a) val arraySlice = Word8ArraySlice.slice val arraySliceLength = Word8ArraySlice.length val arraySliceVector = Word8ArraySlice.vector val copyIntoSlice = fn (v, sl) => let val (a, i, _) = Word8ArraySlice.base sl in Word8Array.copyVec {src = v, dst = a, di = i} end)

  (* ==== BinPrimIO.compare ==== *)
  val eqO = T.eq T.order
  fun p (n : int) : BinPrimIO.pos = Position.fromInt n
  val () = eqO ("BinPrimIO.compare/less", LESS, fn () => BinPrimIO.compare (p 1, p 2))
  val () = eqO ("BinPrimIO.compare/equal", EQUAL, fn () => BinPrimIO.compare (p 7, p 7))
  val () = eqO ("BinPrimIO.compare/greater", GREATER, fn () => BinPrimIO.compare (p 4096, p 0))
  (* a linear ordering: antisymmetric, EQUAL exactly on equal positions,
     transitive; on random offsets *)
  val () = T.seed 7
  val () = T.repeat (40, fn i =>
             T.check ("BinPrimIO.compare/linear-order-" ^ Int.toString i,
                      fn () => let
                                 val a = p (T.range (0, 100)) val b = p (T.range (0, 100)) val c = p (T.range (0, 100))
                                 fun flip LESS = GREATER | flip GREATER = LESS | flip EQUAL = EQUAL
                               in
                                 BinPrimIO.compare (a, b) = flip (BinPrimIO.compare (b, a))
                                 andalso (BinPrimIO.compare (a, b) = EQUAL) = (a = b)
                                 andalso (BinPrimIO.compare (a, b) <> LESS orelse BinPrimIO.compare (b, c) <> LESS
                                          orelse BinPrimIO.compare (a, c) = LESS)
                                 andalso BinPrimIO.compare (a, b) = Position.compare (a, b)
                               end))
end
