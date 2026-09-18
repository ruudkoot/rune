(* The readers and writers of one element type (signature PRIM_IO). A reader
   made here offers the operations its argument gives and those that can be
   built from them (augmentReader); the rest are NONE. *)
functor RunePrimIOFn (structure V : MONO_VECTOR
                      structure A : MONO_ARRAY where type elem = V.elem where type vector = V.vector
                      structure VS : MONO_VECTOR_SLICE where type elem = V.elem where type vector = V.vector
                      structure AS : MONO_ARRAY_SLICE where type elem = V.elem
                                     where type array = A.array where type vector = V.vector
                                     where type vector_slice = VS.slice
                      val someElem : V.elem) =
struct
  type elem = V.elem
  type vector = V.vector
  type vector_slice = VS.slice
  type array = A.array
  type array_slice = AS.slice
  type pos = Position.int
  val compare = Position.compare

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

  (* A reader over a vector that is there already. *)
  fun openVector v =
    let
      val pos = ref 0
      fun readVec n =
        let
          val left = V.length v - !pos
          val k = if n < left then n else left
          val r = VS.vector (VS.slice (v, !pos, SOME k))
        in pos := !pos + k; r end
      fun readArr sl =
        let
          val r = readVec (AS.length sl)
        in AS.copyVec {src = VS.full r, dst = #1 (AS.base sl), di = #2 (AS.base sl)}; V.length r end
    in
      RD {name = "<vector>", chunkSize = V.length v,
          readVec = SOME readVec, readArr = SOME readArr,
          readVecNB = SOME (SOME o readVec), readArrNB = SOME (SOME o readArr),
          block = SOME (fn () => ()), canInput = SOME (fn () => true),
          avail = fn () => SOME (V.length v - !pos),
          getPos = SOME (fn () => Position.fromInt (!pos)),
          setPos = SOME (fn p => pos := Position.toInt p),
          endPos = SOME (fn () => Position.fromInt (V.length v)),
          verifyPos = SOME (fn () => Position.fromInt (!pos)),
          close = fn () => pos := V.length v,
          ioDesc = NONE}
    end

  fun nullRd () =
    RD {name = "<nullRd>", chunkSize = 1,
        readVec = SOME (fn _ => V.fromList []), readArr = SOME (fn _ => 0),
        readVecNB = SOME (fn _ => SOME (V.fromList [])), readArrNB = SOME (fn _ => SOME 0),
        block = SOME (fn () => ()), canInput = SOME (fn () => true), avail = fn () => SOME 0,
        getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
        close = fn () => (), ioDesc = NONE}

  fun nullWr () =
    WR {name = "<nullWr>", chunkSize = 1,
        writeVec = SOME VS.length, writeArr = SOME AS.length,
        writeVecNB = SOME (SOME o VS.length), writeArrNB = SOME (SOME o AS.length),
        block = SOME (fn () => ()), canOutput = SOME (fn () => true),
        getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
        close = fn () => (), ioDesc = NONE}

  (* The operations that can be had from the others. A vector read becomes an
     array read by copying, and the other way round; a non-blocking operation
     is only added where the reader can say beforehand that it will not wait. *)
  fun augmentReader (RD rd) =
    let
      val {readVec, readArr, readVecNB, readArrNB, canInput, ...} = rd
      val vecFromArr =
        case readArr of
          NONE => NONE
        | SOME f =>
            SOME (fn n =>
              let
                val a = A.array (n, someElem)
                val k = f (AS.full a)
              in AS.vector (AS.slice (a, 0, SOME k)) end)
      val arrFromVec =
        case readVec of
          NONE => NONE
        | SOME f =>
            SOME (fn sl =>
              let
                val v = f (AS.length sl)
                val (a, i, _) = AS.base sl
              in AS.copyVec {src = VS.full v, dst = a, di = i}; V.length v end)
      fun nb (which, blocking) =
        case (which, blocking, canInput) of
          (SOME f, _, _) => SOME f
        | (NONE, SOME f, SOME ready) => SOME (fn x => if ready () then SOME (f x) else NONE)
        | _ => NONE
      val readVec' = case readVec of SOME f => SOME f | NONE => vecFromArr
      val readArr' = case readArr of SOME f => SOME f | NONE => arrFromVec
    in
      RD {name = #name rd, chunkSize = #chunkSize rd,
          readVec = readVec', readArr = readArr',
          readVecNB = nb (readVecNB, readVec'), readArrNB = nb (readArrNB, readArr'),
          block = #block rd, canInput = canInput, avail = #avail rd,
          getPos = #getPos rd, setPos = #setPos rd, endPos = #endPos rd,
          verifyPos = #verifyPos rd, close = #close rd, ioDesc = #ioDesc rd}
    end

  fun augmentWriter (WR wr) =
    let
      val {writeVec, writeArr, writeVecNB, writeArrNB, canOutput, ...} = wr
      val vecFromArr =
        case writeArr of
          NONE => NONE
        | SOME f =>
            SOME (fn sl =>
              let
                val v = VS.vector sl
                val a = A.array (V.length v, someElem)
              in A.copyVec {src = v, dst = a, di = 0}; f (AS.full a) end)
      val arrFromVec =
        case writeVec of
          NONE => NONE
        | SOME f => SOME (fn sl => f (VS.full (AS.vector sl)))
      fun nb (which, blocking) =
        case (which, blocking, canOutput) of
          (SOME f, _, _) => SOME f
        | (NONE, SOME f, SOME ready) => SOME (fn x => if ready () then SOME (f x) else NONE)
        | _ => NONE
      val writeVec' = case writeVec of SOME f => SOME f | NONE => vecFromArr
      val writeArr' = case writeArr of SOME f => SOME f | NONE => arrFromVec
    in
      WR {name = #name wr, chunkSize = #chunkSize wr,
          writeVec = writeVec', writeArr = writeArr',
          writeVecNB = nb (writeVecNB, writeVec'), writeArrNB = nb (writeArrNB, writeArr'),
          block = #block wr, canOutput = canOutput,
          getPos = #getPos wr, setPos = #setPos wr, endPos = #endPos wr,
          verifyPos = #verifyPos wr, close = #close wr, ioDesc = #ioDesc wr}
    end
end
