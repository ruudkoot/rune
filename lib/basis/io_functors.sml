(* Readers and writers of a new element type: the `PRIM_IO` of it, built from
   the vectors, arrays and slices of that type.

   `TextPrimIO` and `BinPrimIO` are what this functor would give for `char`
   and `Word8.word`; it is here for a program that wants the stack over
   elements of its own. `someElem` is a value of the type, which the reader
   needs to make an array to read into, and `pos` and `compare` say what a
   position in such a source is.

   Status: optional

   See also: `PRIM_IO`, `STREAM_IO` *)
functor PrimIO (structure Vector : MONO_VECTOR
                structure VectorSlice : MONO_VECTOR_SLICE
                structure Array : MONO_ARRAY
                structure ArraySlice : MONO_ARRAY_SLICE
                sharing type Vector.elem = VectorSlice.elem = Array.elem = ArraySlice.elem
                sharing type Vector.vector = VectorSlice.vector = Array.vector = ArraySlice.vector
                sharing type VectorSlice.slice = ArraySlice.vector_slice
                sharing type Array.array = ArraySlice.array
                val someElem : Vector.elem
                eqtype pos
                val compare : pos * pos -> order) : PRIM_IO =
  RunePrimIOFn (structure V = Vector
                structure A = Array
                structure VS = VectorSlice
                structure AS = ArraySlice
                val someElem = someElem
                type pos = pos
                val compare = compare
                val index = NONE)

(* Functional streams over a `PRIM_IO` of a new element type: the `STREAM_IO`
   of it.

   Deviation: `StreamIO/takes-the-slice-structures`. The specification gives
   this functor no slice structures, yet it has to hand its writer vector
   slices, and `PRIM_IO` offers no way to make one. Like MLton's, this one
   also takes `VectorSlice` and `ArraySlice`, and its `PrimIO` must have
   positions of the integer type of `Position`, which `filePosIn` counts with.

   Implementation: `StreamIO/LINE_BUF-is-BLOCK_BUF`. No element of an
   arbitrary type is known to be a newline, so a stream built here treats
   `LINE_BUF` as a synonym for `BLOCK_BUF`, as the specification asks of a
   binary stream.

   Status: optional

   See also: `STREAM_IO`, `PRIM_IO`, `IMPERATIVE_IO` *)
functor StreamIO (structure PrimIO : PRIM_IO
                  structure Vector : MONO_VECTOR
                  structure VectorSlice : MONO_VECTOR_SLICE
                  structure Array : MONO_ARRAY
                  structure ArraySlice : MONO_ARRAY_SLICE
                  sharing type PrimIO.elem = Vector.elem = VectorSlice.elem = Array.elem = ArraySlice.elem
                  sharing type PrimIO.vector = Vector.vector = VectorSlice.vector = Array.vector = ArraySlice.vector
                  sharing type PrimIO.vector_slice = VectorSlice.slice
                  sharing type PrimIO.array = Array.array
                  val someElem : PrimIO.elem) : STREAM_IO =
  RuneStreamIOFn (structure PIO = PrimIO
                  structure V = Vector
                  structure VS = VectorSlice
                  val advance = NONE
                  (* "For binary streams, LINE_BUF mode should be treated as a
                     synonym for BLOCK_BUF": no element is a newline *)
                  val isNewline = fn _ => false)

(* Imperative streams over a `STREAM_IO` of a new element type: what
   `TEXT_IO` and `BIN_IO` are for characters and bytes.

   Deviation: `ImperativeIO/not-sealed`. The result is not ascribed
   `IMPERATIVE_IO`: the library declares that signature after the structures
   that would need it. It matches it, which the suite checks.

   Status: optional

   See also: `IMPERATIVE_IO`, `STREAM_IO`, `TEXT_IO`, `BIN_IO` *)
functor ImperativeIO (structure StreamIO : STREAM_IO
                      structure Vector : MONO_VECTOR
                      structure Array : MONO_ARRAY
                      sharing type StreamIO.elem = Vector.elem = Array.elem
                      sharing type StreamIO.vector = Vector.vector = Array.vector) =
  RuneImperativeIOFn (structure SIO = StreamIO structure V = Vector)
