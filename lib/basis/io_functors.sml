(* The optional functors of the specification that build the I/O stack for
   other element types: PrimIO, StreamIO and ImperativeIO, on the functors
   TextIO and BinIO are made of.

   ImperativeIO and PrimIO take the arguments of the specification. The
   specification's StreamIO gets no slice structures, yet it must hand its
   writer vector slices (PRIM_IO has no way to make one); like MLton's, this
   one also takes VectorSlice and ArraySlice, and its PrimIO has positions of
   type Position.int, which filePosIn counts with. ImperativeIO is not
   ascribed IMPERATIVE_IO, a signature of the specification that the library
   declares after its structures; it matches it. *)
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

functor StreamIO (structure PrimIO : PRIM_IO where type pos = Position.int
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
                  (* "For binary streams, LINE_BUF mode should be treated as a
                     synonym for BLOCK_BUF": no element is a newline *)
                  val isNewline = fn _ => false)

functor ImperativeIO (structure StreamIO : STREAM_IO
                      structure Vector : MONO_VECTOR
                      structure Array : MONO_ARRAY
                      sharing type StreamIO.elem = Vector.elem = Array.elem
                      sharing type StreamIO.vector = Vector.vector = Array.vector) =
  RuneImperativeIOFn (structure SIO = StreamIO structure V = Vector)
