(* The functional input streams of text-io-fn.sml (StreamIO, from its
   instream type to mkInstream), copied into a standalone program twice: Old
   as in 110.99.9 and legacy main, New with fix.diff. Only the cleaner
   registry (CleanIO) is stubbed. Both run over real readers: openVector, the
   reader of a file (TextIO.StreamIO.getReader), and readers of random
   strings and chunk sizes. Old should lose input as the Basis does; New
   should not, and should count all that can be read. Run: sml fix-check.sml
   (it writes and removes a file fix-check.tmp in the current directory). *)
structure Old = struct
    structure PIO = TextPrimIO
    structure V = CharVector
    structure VS = CharVectorSlice
    structure CleanIO = struct
	type tag = unit
	fun addCleaner _ = ()
	fun removeCleaner _ = ()
      end
    val vecExtract = VS.vector o VS.slice
    val vecSub = V.sub
    val empty = ""
    type vector = V.vector
    type reader = PIO.reader
    type pos = PIO.pos
      (* maximum size of an input request *)
	val maxInputSz = Position.fromInt V.maxLen

      (*** Functional input streams ***
       ** We represent an instream by a pointer to a buffer and an offset
       ** into the buffer.  The buffers are chained by the "more" field from
       ** the beginning of the stream towards the end.  If the "more" field
       ** is EOS, then it refers to an empty buffer (consuming the EOF marker
       ** involves moving the stream from immeditaly in front of the EOS to
       ** to the empty buffer).  A "more" field of TERMINATED marks a
       ** terminated stream.  We also have the invariant that the "tail"
       ** field of the "info" structure points to a more ref that is either
       ** NOMORE or TERMINATED.
       **)
	datatype instream = ISTRM of (in_buffer * int)
	and in_buffer = IBUF of {
	    basePos : pos option,
	    more : more ref,
	    data : vector,
	    info : info
	  }
	and more
	  = MORE of in_buffer	(* forward link to additional data *)
	  | EOS of in_buffer	(* End of stream marker *)
	  | NOMORE		(* placeholder for forward link *)
	  | TERMINATED		(* termination of the stream *)

	and info = INFO of {
	    reader : reader,
	    readVec : int -> vector,
	    readVecNB : (int -> vector) option,
	    closed : bool ref,
	    getPos : unit -> pos option,
	    tail : more ref ref, (* points to the more cell of the last buffer *)
	    cleanTag : CleanIO.tag
	  }

	fun infoOfIBuf (IBUF{info, ...}) = info
	fun chunkSzOfIBuf buf = let
	      val INFO{reader=PIO.RD{chunkSize, ...}, ...} = infoOfIBuf buf
	      in
		chunkSize
	      end
	fun readVec (IBUF{info=INFO{readVec=f, ...}, ...}) = f

	fun inputExn (INFO{reader=PIO.RD{name, ...}, ...}, mlOp, exn) =
	      raise IO.Io{function=mlOp, name=name, cause=exn}

      (* this exception is raised by readVecNB in the blocking case *)
	exception WouldBlock

	fun extendStream (readFn, mlOp, buf as IBUF{more, info, ...}) = (let
	      val INFO{getPos, tail, ...} = info
              val basePos = getPos()
	      val chunk = readFn (chunkSzOfIBuf buf)
	      val newMore = ref NOMORE
	      val buf' = IBUF{
		      basePos = basePos, data = chunk,
		      more = newMore, info = info
		    }
	      val next = if (V.length chunk = 0) then EOS buf' else MORE buf'
	      in
		more := next;
		tail := newMore;
		next
	      end
		handle ex => inputExn(info, mlOp, ex))

	fun getBuffer (readFn, mlOp) (buf as IBUF{more, info, ...}) = (
	      case !more
	       of TERMINATED => (EOS buf)
		| NOMORE => extendStream (readFn, mlOp, buf)
		| more => more
	      (* end case *))

      (* read a chunk that is at least the specified size *)
	fun readChunk buf = let
	      val INFO{readVec, reader=PIO.RD{chunkSize, ...}, ...} =
		     infoOfIBuf buf
	      in
(* FIXME: what if the rounded size is > maxInputSz? *)
                if (chunkSize <= 1)
                  then (fn n => readVec n)
                  (* round up to next multiple of chunkSize *)
                  else (fn n => readVec(Int.quot((n+chunkSize-1), chunkSize) * chunkSize))
	      end

	fun generalizedInput getBuf = let
	      fun get (ISTRM(buf as IBUF{data, ...}, pos)) = let
		    val len = V.length data
		    in
		      if (pos < len)
			then (vecExtract(data, pos, NONE), ISTRM(buf, len))
			else (case (getBuf buf)
			   of (EOS buf) => (empty, ISTRM(buf, 0))
			    | (MORE rest) => get (ISTRM(rest, 0))
			    | _ => raise Fail "bogus getBuf"
			  (* end case *))
		    end
	      in
		get
	      end

      (* terminate an input stream *)
	fun terminate (INFO{tail, cleanTag, ...}) = (case !tail
	       of (m as ref NOMORE) => (
		    CleanIO.removeCleaner cleanTag;
		    m := TERMINATED)
		| (m as ref TERMINATED) => ()
		| _ => raise Match (* shut up compiler *)
	      (* end case *))

	fun input (strm as ISTRM(buf, _)) =
	      generalizedInput (getBuffer (readVec buf, "input")) strm

	fun input1 (ISTRM(buf, pos)) = let
	      val IBUF{data, more, ...} = buf
	      in
		if (pos < V.length data)
		  then SOME(vecSub(data, pos), ISTRM(buf, pos+1))
		  else (case !more
		     of (MORE buf) => input1 (ISTRM(buf, 0))
		      | (EOS _) => NONE
		      | NOMORE => (
			  case extendStream (readVec buf, "input1", buf)
			   of (MORE rest) => input1 (ISTRM(rest, 0))
			    | _ => NONE
			  (* end case *))
		      | TERMINATED => NONE
		    (* end case *))
	      end

	fun inputN (ISTRM(buf, pos), n) = let
	      fun join (item, (list, strm)) = (item::list, strm)
	      fun inputList (buf as IBUF{data, ...}, i, n) = let
		    val len = V.length data
		    val remain = len-i
		    in
		      if (remain >= n)
			then ([vecExtract(data, i, SOME n)], ISTRM(buf, i+n))
		      else join (
			vecExtract(data, i, NONE),
			nextBuf(buf, n-remain))
		    end
	      and nextBuf (buf as IBUF{more, data, ...}, n) = (case !more
		     of (MORE buf) => inputList (buf, 0, n)
		      | (EOS buf) => ([], ISTRM(buf, 0))
		      | NOMORE => (
			  case extendStream (readVec buf, "inputN", buf)
			   of (MORE rest) => inputList (rest, 0, n)
			    | _ => ([], ISTRM(buf, V.length data))
			  (* end case *))
		      | TERMINATED => ([], ISTRM(buf, V.length data))
		    (* end case *))
	      val (data, strm) = inputList (buf, pos, n)
	      in
		(V.concat data, strm)
	      end

	fun inputAll (strm as ISTRM(buf, _)) = let
	      val INFO{reader=PIO.RD{avail, ...}, ...} = infoOfIBuf buf
 	    (* Read a chunk that is as large as the available input.  Note
	     * that for systems that use CR-LF for #"\n", the size will be
	     * too large, but this should be okay.
	     *)
	      fun bigChunk _ = let
		    val delta = (case avail()
			   of NONE => chunkSzOfIBuf buf
			    | (SOME n) => if (n > maxInputSz)
				then raise Size
				else Position.toInt n
			  (* end case *))
		    in
		      readChunk buf delta
		    end
	      val bigInput =
		    generalizedInput (getBuffer (bigChunk, "inputAll"))
	      fun loop (v, strm) = if (V.length v = 0)
		    then ([], strm)
		    else let val (l, strm') = loop(bigInput strm)
		      in
			(v :: l, strm')
		      end
	      val (data, strm') = loop (bigInput strm)
	      in
		(V.concat data, strm')
	      end
      (* Return SOME k, if k <= amount characters can be read without blocking. *)
	fun canInput (strm as ISTRM(buf, pos), amount) = let
	      val readVecNB = (case buf
		   of (IBUF{info as INFO{readVecNB=NONE, ...}, ...}) =>
			inputExn(info, "canInput", IO.NonblockingNotSupported)
		    | (IBUF{info=INFO{readVecNB=SOME f, ...}, ...}) => f
		  (* end case *))
	      fun tryInput (buf as IBUF{data, ...}, i, n) = let
		    val len = V.length data
		    val remain = len - i
		    in
		      if (remain >= n)
			then SOME n
			else nextBuf (buf, n - remain)
		    end
	      and nextBuf (IBUF{more, ...}, n) = (case !more
		     of (MORE buf) => tryInput (buf, 0, n)
		      | (EOS _) => SOME(amount - n)
		      | TERMINATED => SOME(amount - n)
		      | NOMORE => ((
			  case extendStream (readVecNB, "canInput", buf)
			   of (MORE b) => tryInput (b, 0, n)
			    | _ => SOME(amount - n)
			  (* end case *))
			    handle IO.Io{cause=WouldBlock, ...} => SOME(amount - n))
		    (* end case *))
	      in
		if (amount < 0)
		  then raise Size
		  else tryInput (buf, pos, amount)
	      end
	fun closeIn (ISTRM(buf, _)) = (case (infoOfIBuf buf)
	       of INFO{closed=ref true, ...} => ()
		| (info as INFO{closed, reader=PIO.RD{close, ...}, ...}) => (
		    terminate info;
		    closed := true;
		    close() handle ex => inputExn(info, "closeIn", ex))
	      (* end case *))
	fun endOfStream (ISTRM(buf, pos)) = (case buf
	       of (IBUF{more=ref(MORE _), ...}) => false
		| (IBUF{more, data, info=INFO{closed, ...}, ...}) =>
		    if (pos = V.length data)
		      then (case (!more, !closed)
			 of (NOMORE, false) => (
			      case extendStream (readVec buf, "endOfStream", buf)
			       of (EOS _) => true
				| _ => false
			    (* end case *))
			  | _ => true
			(* end case *))
		      else false
	      (* end case *))
	fun mkInstream (reader, data) = let
	      val PIO.RD{readVec, readVecNB, getPos, setPos, ...} = reader
	      val readVec' = (case readVec
		     of NONE => (fn _ => raise IO.BlockingNotSupported)
		      | (SOME f) => f
		    (* end case *))
	      val readVecNB' = (case readVecNB
		     of NONE => NONE
		      | (SOME f) => SOME(fn arg => case (f arg)
			   of (SOME x) => x
			    | NONE => raise WouldBlock
			  (* end case *))
		    (* end case *))
	      val getPos = (case (getPos, setPos)
		     of (SOME f, SOME _) => (fn () => SOME(f()))
		      | _ => (fn () => NONE)
		    (* end case *))
	      val more = ref NOMORE
	      val closedFlg = ref false
	      val tag = CleanIO.addCleaner {
		      init = fn () => (closedFlg := true),
		      flush = fn () => (),
		      close = fn () => (closedFlg := true)
		    }
	      val info = INFO{
		      reader=reader, readVec=readVec', readVecNB=readVecNB',
		      closed = closedFlg, getPos = getPos, tail = ref more,
		      cleanTag = tag
		    }
(** What should we do about the position when there is initial data?? **)
(** Suggestion: When building a stream with supplied initial data,
 ** nothing can be said about the positions inside that initial
 ** data (who knows where that data even came from!).
 **)
	      val basePos = if (V.length data = 0)
		    then getPos()
		    else NONE
	      in
		ISTRM(
		  IBUF{basePos = basePos, data = data, info = info, more = more},
		  0)
	      end

end
structure New = struct
    structure PIO = TextPrimIO
    structure V = CharVector
    structure VS = CharVectorSlice
    structure CleanIO = struct
	type tag = unit
	fun addCleaner _ = ()
	fun removeCleaner _ = ()
      end
    val vecExtract = VS.vector o VS.slice
    val vecSub = V.sub
    val empty = ""
    type vector = V.vector
    type reader = PIO.reader
    type pos = PIO.pos
      (* maximum size of an input request *)
	val maxInputSz = Position.fromInt V.maxLen

      (*** Functional input streams ***
       ** We represent an instream by a pointer to a buffer and an offset
       ** into the buffer.  The buffers are chained by the "more" field from
       ** the beginning of the stream towards the end.  If the "more" field
       ** is EOS, then it refers to an empty buffer (consuming the EOF marker
       ** involves moving the stream from immeditaly in front of the EOS to
       ** to the empty buffer).  A "more" field of TERMINATED marks a
       ** terminated stream.  We also have the invariant that the "tail"
       ** field of the "info" structure points to a more ref that is either
       ** NOMORE or TERMINATED.
       **)
	datatype instream = ISTRM of (in_buffer * int)
	and in_buffer = IBUF of {
	    basePos : pos option,
	    more : more ref,
	    data : vector,
	    info : info
	  }
	and more
	  = MORE of in_buffer	(* forward link to additional data *)
	  | EOS of in_buffer	(* End of stream marker *)
	  | NOMORE		(* placeholder for forward link *)
	  | TERMINATED		(* termination of the stream *)

	and info = INFO of {
	    reader : reader,
	    readVec : int -> vector,
	    readVecNB : (int -> vector) option,
	    closed : bool ref,
	    getPos : unit -> pos option,
	    tail : more ref ref, (* points to the more cell of the last buffer *)
	    cleanTag : CleanIO.tag
	  }

	fun infoOfIBuf (IBUF{info, ...}) = info
	fun chunkSzOfIBuf buf = let
	      val INFO{reader=PIO.RD{chunkSize, ...}, ...} = infoOfIBuf buf
	      in
		chunkSize
	      end
	fun readVec (IBUF{info=INFO{readVec=f, ...}, ...}) = f

	fun inputExn (INFO{reader=PIO.RD{name, ...}, ...}, mlOp, exn) =
	      raise IO.Io{function=mlOp, name=name, cause=exn}

      (* this exception is raised by readVecNB in the blocking case *)
	exception WouldBlock

	fun extendStream (readFn, mlOp, buf as IBUF{more, info, ...}) = (let
	      val INFO{getPos, tail, ...} = info
              val basePos = getPos()
	      val chunk = readFn (chunkSzOfIBuf buf)
	      val newMore = ref NOMORE
	      val buf' = IBUF{
		      basePos = basePos, data = chunk,
		      more = newMore, info = info
		    }
	      val next = if (V.length chunk = 0) then EOS buf' else MORE buf'
	      in
		more := next;
		tail := newMore;
		next
	      end
		handle ex => inputExn(info, mlOp, ex))

	fun getBuffer (readFn, mlOp) (buf as IBUF{more, info, ...}) = (
	      case !more
	       of TERMINATED => (EOS buf)
		| NOMORE => extendStream (readFn, mlOp, buf)
		| more => more
	      (* end case *))

      (* read a chunk that is at least the specified size *)
	fun readChunk buf = let
	      val INFO{readVec, reader=PIO.RD{chunkSize, ...}, ...} =
		     infoOfIBuf buf
	      in
(* FIXME: what if the rounded size is > maxInputSz? *)
                if (chunkSize <= 1)
                  then (fn n => readVec n)
                  (* round up to next multiple of chunkSize *)
                  else (fn n => readVec(Int.quot((n+chunkSize-1), chunkSize) * chunkSize))
	      end

	fun generalizedInput getBuf = let
	      fun get (ISTRM(buf as IBUF{data, ...}, pos)) = let
		    val len = V.length data
		    in
		      if (pos < len)
			then (vecExtract(data, pos, NONE), ISTRM(buf, len))
			else (case (getBuf buf)
			   of (EOS buf) => (empty, ISTRM(buf, 0))
			    | (MORE rest) => get (ISTRM(rest, 0))
			    | _ => raise Fail "bogus getBuf"
			  (* end case *))
		    end
	      in
		get
	      end

      (* terminate an input stream *)
	fun terminate (INFO{tail, cleanTag, ...}) = (case !tail
	       of (m as ref NOMORE) => (
		    CleanIO.removeCleaner cleanTag;
		    m := TERMINATED)
		| (m as ref TERMINATED) => ()
		| _ => raise Match (* shut up compiler *)
	      (* end case *))

	fun input (strm as ISTRM(buf, _)) =
	      generalizedInput (getBuffer (readVec buf, "input")) strm

	fun input1 (ISTRM(buf, pos)) = let
	      val IBUF{data, more, ...} = buf
	      in
		if (pos < V.length data)
		  then SOME(vecSub(data, pos), ISTRM(buf, pos+1))
		  else (case !more
		     of (MORE buf) => input1 (ISTRM(buf, 0))
		      | (EOS _) => NONE
		      | NOMORE => (
			  case extendStream (readVec buf, "input1", buf)
			   of (MORE rest) => input1 (ISTRM(rest, 0))
			    | _ => NONE
			  (* end case *))
		      | TERMINATED => NONE
		    (* end case *))
	      end

	fun inputN (ISTRM(buf, pos), n) = let
	      fun join (item, (list, strm)) = (item::list, strm)
	      fun inputList (buf as IBUF{data, ...}, i, n) = let
		    val len = V.length data
		    val remain = len-i
		    in
		      if (remain >= n)
			then ([vecExtract(data, i, SOME n)], ISTRM(buf, i+n))
		      else join (
			vecExtract(data, i, NONE),
			nextBuf(buf, n-remain))
		    end
	      and nextBuf (buf as IBUF{more, data, ...}, n) = (case !more
		     of (MORE buf) => inputList (buf, 0, n)
		      | (EOS buf) => ([], ISTRM(buf, 0))
		      | NOMORE => (
			  case extendStream (readVec buf, "inputN", buf)
			   of (MORE rest) => inputList (rest, 0, n)
			    | _ => ([], ISTRM(buf, V.length data))
			  (* end case *))
		      | TERMINATED => ([], ISTRM(buf, V.length data))
		    (* end case *))
	      val (data, strm) = inputList (buf, pos, n)
	      in
		(V.concat data, strm)
	      end

	fun inputAll (strm as ISTRM(buf, _)) = let
	      val INFO{reader=PIO.RD{avail, ...}, ...} = infoOfIBuf buf
 	    (* Read a chunk that is as large as the available input.  Note
	     * that for systems that use CR-LF for #"\n", the size will be
	     * too large, but this should be okay.
	     *)
	      fun bigChunk _ = let
		    val delta = (case avail()
			   of NONE => chunkSzOfIBuf buf
			    | (SOME n) => if (n > maxInputSz)
				then raise Size
				else Position.toInt n
			  (* end case *))
		    in
		      readChunk buf delta
		    end
	      val bigInput =
		    generalizedInput (getBuffer (bigChunk, "inputAll"))
	      fun loop (v, strm) = if (V.length v = 0)
		    then ([], strm)
		    else let val (l, strm') = loop(bigInput strm)
		      in
			(v :: l, strm')
		      end
	      val (data, strm') = loop (bigInput strm)
	      in
		(V.concat data, strm')
	      end
      (* Return SOME k, if k <= amount characters can be read without blocking. *)
	fun canInput (strm as ISTRM(buf, pos), amount) = let
	      val readVecNB = (case buf
		   of (IBUF{info as INFO{readVecNB=NONE, ...}, ...}) =>
			inputExn(info, "canInput", IO.NonblockingNotSupported)
		    | (IBUF{info=INFO{readVecNB=SOME f, ...}, ...}) => f
		  (* end case *))
	    (* n is what remains of amount to be found, from position i of buf *)
	      fun tryInput (buf as IBUF{data, ...}, i, n) = let
		    val len = V.length data
		    val remain = len - i
		    in
		      if (remain >= n)
			then SOME amount
			else nextBuf (buf, n - remain)
		    end
	      and nextBuf (buf as IBUF{more, ...}, n) = (case !more
		     of (MORE buf) => tryInput (buf, 0, n)
		      | (EOS _) => SOME(amount - n)
		      | TERMINATED => SOME(amount - n)
		      | NOMORE => ((
			  case extendStream (readVecNB, "canInput", buf)
			   of (MORE b) => tryInput (b, 0, n)
			    | _ => SOME(amount - n)
			  (* end case *))
			    handle IO.Io{cause=WouldBlock, ...} => SOME(amount - n))
		    (* end case *))
	      in
		if (amount < 0)
		  then raise Size
		  else tryInput (buf, pos, amount)
	      end
	fun closeIn (ISTRM(buf, _)) = (case (infoOfIBuf buf)
	       of INFO{closed=ref true, ...} => ()
		| (info as INFO{closed, reader=PIO.RD{close, ...}, ...}) => (
		    terminate info;
		    closed := true;
		    close() handle ex => inputExn(info, "closeIn", ex))
	      (* end case *))
	fun endOfStream (ISTRM(buf, pos)) = (case buf
	       of (IBUF{more=ref(MORE _), ...}) => false
		| (IBUF{more, data, info=INFO{closed, ...}, ...}) =>
		    if (pos = V.length data)
		      then (case (!more, !closed)
			 of (NOMORE, false) => (
			      case extendStream (readVec buf, "endOfStream", buf)
			       of (EOS _) => true
				| _ => false
			    (* end case *))
			  | _ => true
			(* end case *))
		      else false
	      (* end case *))
	fun mkInstream (reader, data) = let
	      val PIO.RD{readVec, readVecNB, getPos, setPos, ...} = reader
	      val readVec' = (case readVec
		     of NONE => (fn _ => raise IO.BlockingNotSupported)
		      | (SOME f) => f
		    (* end case *))
	      val readVecNB' = (case readVecNB
		     of NONE => NONE
		      | (SOME f) => SOME(fn arg => case (f arg)
			   of (SOME x) => x
			    | NONE => raise WouldBlock
			  (* end case *))
		    (* end case *))
	      val getPos = (case (getPos, setPos)
		     of (SOME f, SOME _) => (fn () => SOME(f()))
		      | _ => (fn () => NONE)
		    (* end case *))
	      val more = ref NOMORE
	      val closedFlg = ref false
	      val tag = CleanIO.addCleaner {
		      init = fn () => (closedFlg := true),
		      flush = fn () => (),
		      close = fn () => (closedFlg := true)
		    }
	      val info = INFO{
		      reader=reader, readVec=readVec', readVecNB=readVecNB',
		      closed = closedFlg, getPos = getPos, tail = ref more,
		      cleanTag = tag
		    }
(** What should we do about the position when there is initial data?? **)
(** Suggestion: When building a stream with supplied initial data,
 ** nothing can be said about the positions inside that initial
 ** data (who knows where that data even came from!).
 **)
	      val basePos = if (V.length data = 0)
		    then getPos()
		    else NONE
	      in
		ISTRM(
		  IBUF{basePos = basePos, data = data, info = info, more = more},
		  0)
	      end

end

fun opt NONE = "NONE" | opt (SOME n) = "SOME " ^ Int.toString n
val file = "fix-check.tmp"
val text = CharVector.tabulate (10000, fn i => Char.chr (97 + i mod 26))
val () = let val out = TextIO.openOut file in TextIO.output (out, text); TextIO.closeOut out end
fun fileReader () =
      let val s = TextIO.getInstream (TextIO.openIn file)
          val (r, _) = TextIO.StreamIO.getReader s
      in r end

(* each as a structure argument, so that Old and New run the same code *)
signature S = sig
  type instream
  val mkInstream : TextPrimIO.reader * string -> instream
  val input : instream -> string * instream
  val input1 : instream -> (char * instream) option
  val inputAll : instream -> string * instream
  val canInput : instream * int -> int option
end
functor Check (structure S : S val name : string) = struct
  val s = S.mkInstream (TextPrimIO.openVector "ab", "")
  val a = S.canInput (s, 5)
  val () = print (concat [name, ": openVector \"ab\": canInput (s, 5) = ", opt a,
                          ", then input s = \"", #1 (S.input s), "\"\n"])
  val s = S.mkInstream (fileReader (), "")
  val a = S.canInput (s, 6000)
  val (all, _) = S.inputAll s
  val () = print (concat [name, ": file of 10000 characters: canInput (s, 6000) = ", opt a,
                          ", then inputAll s has ", Int.toString (size all), " characters",
                          if all = text then " (all of them)" else "", "\n"])
  (* random strings, chunk sizes and operations, over readers that never
   * block: what is read must be the string, and canInput (s, n) must be
   * SOME (min (n, what is left))
   *)
  val rng = Random.rand (3, 5)
  fun reader (src, chunk) =
        let val pos = ref 0
            fun readV n = let val m = Int.min (n, size src - !pos)
                              val v = String.substring (src, !pos, m)
                          in pos := !pos + m; v end
        in TextPrimIO.RD {name = "random", chunkSize = chunk, readVec = SOME readV, readArr = NONE,
                          readVecNB = SOME (SOME o readV), readArrNB = NONE, block = NONE,
                          canInput = SOME (fn () => true), avail = fn () => SOME (Position.fromInt (size src - !pos)),
                          getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                          close = fn () => (), ioDesc = NONE}
        end
  val lost = ref 0
  val miscounted = ref 0
  fun trial () =
        let val len = Random.randRange (0, 300) rng
            val src = CharVector.tabulate (len, fn _ => Char.chr (Random.randRange (97, 122) rng))
            val chunk = Random.randRange (1, 9) rng
            val wrongCount = ref false
            fun go (s, acc, k) =
                  if k = 0 then concat (rev (#1 (S.inputAll s) :: acc))
                  else case Random.randRange (0, 2) rng
                        of 0 => let val n = Random.randRange (0, 40) rng
                                    val left = len - size (concat acc)
                                in
                                  if S.canInput (s, n) <> SOME (Int.min (n, left)) then wrongCount := true else ();
                                  go (s, acc, k - 1)
                                end
                         | 1 => (case S.input1 s of SOME (c, s') => go (s', String.str c :: acc, k - 1)
                                                  | NONE => go (s, acc, k - 1))
                         | _ => let val (v, s') = S.input s in go (s', v :: acc, k - 1) end
        in
          if go (S.mkInstream (reader (src, chunk), ""), [], Random.randRange (0, 20) rng) = src then ()
          else lost := !lost + 1;
          if !wrongCount then miscounted := !miscounted + 1 else ()
        end
  val () = List.app trial (List.tabulate (10000, fn _ => ()))
  val () = print (concat [name, ": 10000 random readers: input lost or changed in ", Int.toString (!lost),
                          ", canInput (s, n) not SOME (min (n, what is left)) in ", Int.toString (!miscounted), "\n"])
end
structure O = Check (structure S = Old val name = "Old")
structure N = Check (structure S = New val name = "New")
val () = OS.FileSys.remove file
val () = OS.Process.exit OS.Process.success
