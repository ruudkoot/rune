(* The readers and writers of one element type (signature PRIM_IO). A reader
   made here offers the operations its argument gives and those that can be
   built from them (augmentReader); the rest are NONE. The positions are of
   any type; index, when the argument has it, turns an index of a vector
   into a position and back, which the reader of openVector needs to have
   positions at all. *)
functor RunePrimIOFn (structure V : MONO_VECTOR
                      structure A : MONO_ARRAY where type elem = V.elem where type vector = V.vector
                      structure VS : MONO_VECTOR_SLICE where type elem = V.elem where type vector = V.vector
                      structure AS : MONO_ARRAY_SLICE where type elem = V.elem
                                     where type array = A.array where type vector = V.vector
                                     where type vector_slice = VS.slice
                      val someElem : V.elem
                      eqtype pos
                      val compare : pos * pos -> order
                      val index : {fromInt : int -> pos, toInt : pos -> int} option) =
struct
  type elem = V.elem
  type vector = V.vector
  type vector_slice = VS.slice
  type array = A.array
  type array_slice = AS.slice
  type pos = pos
  val compare = compare

  datatype reader =
    RD of {name : string,
           chunkSize : int,
           readVec : (int -> vector) option,
           readArr : (array_slice -> int) option,
           readVecNB : (int -> vector option) option,
           readArrNB : (array_slice -> int option) option,
           block : (unit -> unit) option,
           canInput : (unit -> bool) option,
           avail : unit -> int option,
           getPos : (unit -> pos) option,
           setPos : (pos -> unit) option,
           endPos : (unit -> pos) option,
           verifyPos : (unit -> pos) option,
           close : unit -> unit,
           ioDesc : RuneIODesc.iodesc option}

  datatype writer =
    WR of {name : string,
           chunkSize : int,
           writeVec : (vector_slice -> int) option,
           writeArr : (array_slice -> int) option,
           writeVecNB : (vector_slice -> int option) option,
           writeArrNB : (array_slice -> int option) option,
           block : (unit -> unit) option,
           canOutput : (unit -> bool) option,
           getPos : (unit -> pos) option,
           setPos : (pos -> unit) option,
           endPos : (unit -> pos) option,
           verifyPos : (unit -> pos) option,
           close : unit -> unit,
           ioDesc : RuneIODesc.iodesc option}

  (* "A reader is required to raise IO.Io if any of its functions, except
     close or getPos, is invoked after a call to close. A writer is required
     to raise IO.Io if any of its functions, except close, is invoked after a
     call to close. In both cases, the cause field of the exception should
     be IO.ClosedStream." guard (closed, name) function f: f, checked. *)
  fun guard (closed, name) function f =
    fn x => if !closed then raise IO.Io {name = name, function = function, cause = IO.ClosedStream} else f x

  (* copyIn (v, sl): v at the start of sl, which is at least as long. *)
  fun copyIn (v, sl) =
    let val (a, i, _) = AS.base sl in AS.copyVec {src = VS.full v, dst = a, di = i}; V.length v end

  (* A reader over a vector that is there already. *)
  fun openVector v =
    let
      val name = "<vector>"
      val closed = ref false
      val pos = ref 0
      fun g function f = guard (closed, name) function f
      fun take n =
        let
          val left = V.length v - !pos
          val k = if n < left then n else left
          val r = VS.vector (VS.slice (v, !pos, SOME k))
        in pos := !pos + k; r end
      fun readVec n = if n < 0 then raise Size else take n
      fun readArr sl = copyIn (take (AS.length sl), sl)
    in
      RD {name = name, chunkSize = if V.length v < 1 then 1 else V.length v,
          readVec = SOME (g "readVec" readVec), readArr = SOME (g "readArr" readArr),
          readVecNB = SOME (g "readVecNB" (SOME o readVec)), readArrNB = SOME (g "readArrNB" (SOME o readArr)),
          block = SOME (g "block" (fn () => ())), canInput = SOME (g "canInput" (fn () => true)),
          avail = g "avail" (fn () => SOME (V.length v - !pos)),
          getPos = Option.map (fn {fromInt, ...} => fn () => fromInt (!pos)) index,
          setPos = Option.map (fn {toInt, ...} =>
                                 g "setPos" (fn p => let val i = toInt p
                                                     in if i < 0 orelse i > V.length v then raise Subscript else pos := i end))
                              index,
          endPos = Option.map (fn {fromInt, ...} => g "endPos" (fn () => fromInt (V.length v))) index,
          verifyPos = Option.map (fn {fromInt, ...} => g "verifyPos" (fn () => fromInt (!pos))) index,
          close = fn () => closed := true,
          ioDesc = NONE}
    end

  (* "The reader nullRd acts like a reader that is always at end-of-stream.
     The writer nullWr serves as a sink"; closed, they behave "the same as
     any other closed reader or writer". *)
  fun nullRd () =
    let
      val name = "<nullRd>"
      val closed = ref false
      fun g function f = guard (closed, name) function f
    in
      RD {name = name, chunkSize = 1,
          readVec = SOME (g "readVec" (fn n => if n < 0 then raise Size else V.fromList [])),
          readArr = SOME (g "readArr" (fn _ => 0)),
          readVecNB = SOME (g "readVecNB" (fn n => if n < 0 then raise Size else SOME (V.fromList []))),
          readArrNB = SOME (g "readArrNB" (fn _ => SOME 0)),
          block = SOME (g "block" (fn () => ())), canInput = SOME (g "canInput" (fn () => true)),
          avail = g "avail" (fn () => SOME 0),
          getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
          close = fn () => closed := true, ioDesc = NONE}
    end

  fun nullWr () =
    let
      val name = "<nullWr>"
      val closed = ref false
      fun g function f = guard (closed, name) function f
    in
      WR {name = name, chunkSize = 1,
          writeVec = SOME (g "writeVec" VS.length), writeArr = SOME (g "writeArr" AS.length),
          writeVecNB = SOME (g "writeVecNB" (SOME o VS.length)), writeArrNB = SOME (g "writeArrNB" (SOME o AS.length)),
          block = SOME (g "block" (fn () => ())), canOutput = SOME (g "canOutput" (fn () => true)),
          getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
          close = fn () => closed := true, ioDesc = NONE}
    end

  (* first [a, b, ...]: the first operation that is there; mapOpt f: f over
     one that may be missing. *)
  fun first [] = NONE
    | first (SOME f :: _) = SOME f
    | first (NONE :: rest) = first rest
  fun mapOpt _ NONE = NONE
    | mapOpt f (SOME x) = SOME (f x)
  (* blocking (block, f): an operation that waits, from block and the
     non-blocking f; nonBlocking (ready, f): one that does not, from a test
     that the blocking f will not wait. *)
  fun blocking (b, f) x =
    let fun go () = case f x of SOME r => r | NONE => (b (); go ())
    in b (); go () end
  fun nonBlocking (ready, f) x = if ready () then SOME (f x) else NONE

  (* The operations that can be had from the others, following the table of
     the specification: an operation the reader has is kept as it is; a vector
     read becomes an array read by copying, and the other way round; a
     blocking read is a non-blocking one after block; a non-blocking read is
     a blocking one that canInput says will not wait. *)
  fun augmentReader (RD rd) =
    let
      val {readVec, readArr, readVecNB, readArrNB, block, canInput, ...} = rd
      fun vecOfArr f n =
        let val a = A.array (n, someElem) val k = f (AS.full a)
        in AS.vector (AS.slice (a, 0, SOME k)) end
      fun arrOfVec f sl = copyIn (f (AS.length sl), sl)
      fun vecOfArrNB f n =
        let val a = A.array (n, someElem)
        in case f (AS.full a) of SOME k => SOME (AS.vector (AS.slice (a, 0, SOME k))) | NONE => NONE end
      fun arrOfVecNB f sl = case f (AS.length sl) of SOME v => SOME (copyIn (v, sl)) | NONE => NONE
      fun withBlock (SOME f) = (case block of SOME b => SOME (blocking (b, f)) | NONE => NONE)
        | withBlock NONE = NONE
      fun withReady (SOME f) = (case canInput of SOME ready => SOME (nonBlocking (ready, f)) | NONE => NONE)
        | withReady NONE = NONE
    in
      RD {name = #name rd, chunkSize = #chunkSize rd,
          readVec = first [readVec, mapOpt vecOfArr readArr, withBlock readVecNB, withBlock (mapOpt vecOfArrNB readArrNB)],
          readArr = first [readArr, mapOpt arrOfVec readVec, withBlock readArrNB, withBlock (mapOpt arrOfVecNB readVecNB)],
          readVecNB = first [readVecNB, mapOpt vecOfArrNB readArrNB, withReady readVec, withReady (mapOpt vecOfArr readArr)],
          readArrNB = first [readArrNB, mapOpt arrOfVecNB readVecNB, withReady readArr, withReady (mapOpt arrOfVec readVec)],
          block = block, canInput = canInput, avail = #avail rd,
          getPos = #getPos rd, setPos = #setPos rd, endPos = #endPos rd,
          verifyPos = #verifyPos rd, close = #close rd, ioDesc = #ioDesc rd}
    end

  fun augmentWriter (WR wr) =
    let
      val {writeVec, writeArr, writeVecNB, writeArrNB, block, canOutput, ...} = wr
      fun arrayOf sl =
        let val v = VS.vector sl val a = A.array (V.length v, someElem)
        in A.copyVec {src = v, dst = a, di = 0}; AS.full a end
      fun vecOfArr f sl = f (arrayOf sl)
      fun arrOfVec f sl = f (VS.full (AS.vector sl))
      fun withBlock (SOME f) = (case block of SOME b => SOME (blocking (b, f)) | NONE => NONE)
        | withBlock NONE = NONE
      fun withReady (SOME f) = (case canOutput of SOME ready => SOME (nonBlocking (ready, f)) | NONE => NONE)
        | withReady NONE = NONE
    in
      WR {name = #name wr, chunkSize = #chunkSize wr,
          writeVec = first [writeVec, mapOpt vecOfArr writeArr, withBlock writeVecNB, withBlock (mapOpt vecOfArr writeArrNB)],
          writeArr = first [writeArr, mapOpt arrOfVec writeVec, withBlock writeArrNB, withBlock (mapOpt arrOfVec writeVecNB)],
          writeVecNB = first [writeVecNB, mapOpt vecOfArr writeArrNB, withReady writeVec, withReady (mapOpt vecOfArr writeArr)],
          writeArrNB = first [writeArrNB, mapOpt arrOfVec writeVecNB, withReady writeArr, withReady (mapOpt arrOfVec writeVec)],
          block = block, canOutput = canOutput,
          getPos = #getPos wr, setPos = #setPos wr, endPos = #endPos wr,
          verifyPos = #verifyPos wr, close = #close wr, ioDesc = #ioDesc wr}
    end
end
