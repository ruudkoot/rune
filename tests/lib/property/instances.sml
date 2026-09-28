(* The arbitraries of lib/test/property for every type of a free variable of
   the Basis Library's laws (docs/plans/quickcheck.md, M6 and the census): a
   type variable at `int` (D8), a function type by `Arb.function`, and every
   other type by its instance, `XArb.arb` for the type of a structure `X`.
   Each is run as a property through Check, so that what a case makes is
   undone: every value drawn is shown, is equal to itself, and has the same
   observation twice. One line PASS or FAIL for each type, and a line
   `frozen` with a hash of every observation, which frozen.expected holds:
   the generators are frozen (M6), and a change to what they draw changes
   it. The values the process makes from itself (its ids, its host) differ
   from run to run and machine to machine, and are left out of the hash. *)
val failed = ref 0
val observed = ref (0w0 : Word64.word)

fun probeIn (frozen : bool) (name : string, a : 'a Arb.arb) : unit =
  let
    fun sane x =
      let
        val c = #co a x
        val () = if frozen then observed := Random.hash (Word64.xorb (!observed, c)) else ()
      in
        String.size (#show a x) > 0 andalso Arb.equal a (x, x) andalso #co a x = c
      end
    val r = Check.check Check.default name (Prop.forAll a (fn x => Prop.holds (sane x)))
  in
    if Check.passed r then print ("PASS " ^ name ^ "\n")
    else (print (Check.report name r); failed := !failed + 1)
  end
  handle e => (print ("FAIL " ^ name ^ ": " ^ exnName e ^ "\n"); failed := !failed + 1)

fun probe x = probeIn true x
(* made from the process itself *)
fun probeMade x = probeIn false x

val int = IntArb.arb
fun fn1 (a, b) = Arb.function (a, b)

(* the census's types, in the order of the census's count *)
val () = probe ("int", int)
val () = probe ("string", StringArb.arb)
val () = probe ("char", CharArb.arb)
val () = probe ("''a", int)
val () = probe ("char -> bool", fn1 (CharArb.arb, Arb.bool))
val () = probe ("''a list", Arb.list int)
val () = probe ("real", RealArb.arb)
val () = probe ("CharArray.array", CharArrayArb.arb)
val () = probe ("CharArraySlice.slice", CharArraySliceArb.arb)
val () = probe ("word", WordArb.arb)
val () = probe ("CharVectorSlice.slice", CharVectorSliceArb.arb)
val () = probe ("IntInf.int", IntInfArb.arb)
val () = probe ("'a array", Arb.array int)
val () = probe ("'a ArraySlice.slice", Arb.arraySlice int)
val () = probe ("char * ''a -> ''a", fn1 (Arb.pair (CharArb.arb, int), int))
val () = probe ("Substring.substring", SubstringArb.arb)
val () = probe ("IntArray2.array", IntArray2Arb.arb)
val () = probe ("SysWord.word", SysWordArb.arb)
val () = probe ("'a * ''b -> ''b", fn1 (Arb.pair (int, int), int))
val () = probe ("'a -> bool", fn1 (int, Arb.bool))
val () = probe ("'a Array2.array", Arb.array2 int)
val () = probe ("BinIO.instream", SystemArb.binInstream)
val () = probe ("OS.IO.iodesc", SystemArb.iodesc)
val () = probe ("'a -> unit", fn1 (int, Arb.unit))
val () = probe ("Array2.traversal", BasisDataArb.traversal)
val () = probe ("bool", Arb.bool)
val () = probe ("char * char -> order", fn1 (Arb.pair (CharArb.arb, CharArb.arb), Arb.order))
val () = probe ("char -> char", fn1 (CharArb.arb, CharArb.arb))
val () = probe ("char -> unit", fn1 (CharArb.arb, Arb.unit))
val () = probe ("char list", Arb.list CharArb.arb)
val () = probe ("'a -> ''b option", fn1 (int, Arb.option int))
val () = probe ("'a -> 'a", fn1 (int, int))
val () = probe ("IO.buffer_mode", BasisDataArb.bufferMode)
val () = probe ("Posix.TTY.speed", SystemArb.speed)
val () = probe ("Posix.TTY.termios", SystemArb.termios)
val () = probe ("Word8Array.array", Word8ArrayArb.arb)
val () = probe ("'a * 'a -> order", fn1 (Arb.pair (int, int), Arb.order))
val () = probe ("'a * 'b * ''c -> ''c", fn1 (Arb.triple (int, int, int), int))
val () = probe ("'a * 'b -> bool", fn1 (Arb.pair (int, int), Arb.bool))
val () = probe ("'c -> 'a option", fn1 (int, Arb.option int))
val () = probe ("(char, ''a) StringCvt.reader", BasisDataArb.reader)
val () = probe ("BinIO.StreamIO.instream", SystemArb.binStreamInstream)
val () = probe ("BinIO.StreamIO.writer", SystemArb.binWriter)
val () = probe ("BinPrimIO.pos", PositionArb.arb)
val () = probe ("INet6Sock.in6_addr", INet6SockArb.inAddr)
val () = probe ("OS.FileSys.file_id", SystemArb.fileId)
val () = probe ("OS.IO.poll_desc", SystemArb.pollDesc)
val () = probe ("Posix.Error.syserror", SystemArb.syserror)
val () = probe ("Word8.word", Word8Arb.arb)
val () = probe ("int -> char", fn1 (int, CharArb.arb))
val () = probe ("''a list list", Arb.list (Arb.list int))
val () = probe ("''a option", Arb.option int)
val () = probe ("''a ref", Arb.reference int)
val () = probe ("''a vector", Arb.vector int)
val () = probe ("'a * 'b -> unit", fn1 (Arb.pair (int, int), Arb.unit))
val () = probe ("'mode INet6Sock.stream_sock", INet6SockArb.streamSock ())
val () = probe ("'mode INetSock.stream_sock", SystemArb.inetStreamSock ())
val () = probe ("BinIO.StreamIO.outstream", SystemArb.binOutstream)
val () = probe ("CharVectorSlice.slice list", Arb.list CharVectorSliceArb.arb)
val () = probe ("Date.date", DateArb.arb)
val () = probe ("IEEEReal.rounding_mode", IEEERealArb.roundingMode)
val () = probe ("LargeWord.word", LargeWordArb.arb)
val () = probeMade ("NetHostDB.entry", SystemArb.hostEntry)
val () = probe ("NetHostDB.in_addr", SystemArb.inAddr)
val () = probe ("Posix.FileSys.file_desc", SystemArb.fileDesc)
val () = probe ("Posix.IO.lock_type", SystemArb.lockType)
val () = probeMade ("Posix.IO.pid option", Arb.option SystemArb.pid)
val () = probe ("Posix.IO.whence", SystemArb.whence)
val () = probe ("Posix.Signal.signal", SystemArb.signal)
val () = probeMade ("Posix.SysDB.gid", SystemArb.gid)
val () = probeMade ("Posix.SysDB.uid", SystemArb.uid)
val () = probe ("SML90.instream", SML90Arb.instream)
val () = probe ("Socket.AF.addr_family", SystemArb.addrFamily)
val () = probe ("Socket.SOCK.sock_type", SystemArb.sockType)
val () = probe ("Time.time", TimeArb.arb)
val () = probe ("Word8ArraySlice.slice", Word8ArraySliceArb.arb)
val () = probe ("Word8Vector.vector", Word8VectorArb.arb)
val () = probe ("Word8VectorSlice.slice", Word8VectorSliceArb.arb)
val () = probe ("char -> string", fn1 (CharArb.arb, StringArb.arb))
val () = probe ("exn", Arb.exn)
val () = probe ("int * int -> int", fn1 (Arb.pair (int, int), int))
val () = probe ("int list list", Arb.list (Arb.list int))
val () = probe ("string list", Arb.list StringArb.arb)
val () = probe ("unit", Arb.unit)
val () = probe ("Posix.TTY.fieldsOf's record", SystemArb.termiosFields)
val () = probe ("Date.date's record of fields", DateArb.fields)

(* the rest of the families, beyond the census *)
val () = probe ("Int8.int", Int8Arb.arb)
val () = probe ("Int16.int", Int16Arb.arb)
val () = probe ("Int32.int", Int32Arb.arb)
val () = probe ("Int64.int", Int64Arb.arb)
val () = probe ("LargeInt.int", LargeIntArb.arb)
val () = probe ("FixedInt.int", FixedIntArb.arb)
val () = probe ("Word16.word", Word16Arb.arb)
val () = probe ("Word32.word", Word32Arb.arb)
val () = probe ("Word64.word", Word64Arb.arb)
val () = probe ("Real32.real", Real32Arb.arb)
val () = probe ("Real64.real", Real64Arb.arb)
val () = probe ("LargeReal.real", LargeRealArb.arb)
val () = probe ("WideChar.char", WideCharArb.arb)
val () = probe ("WideString.string", WideStringArb.arb)
val () = probe ("WideSubstring.substring", WideSubstringArb.arb)
val () = probe ("CharVector.vector", CharVectorArb.arb)
val () = probe ("CharArray2.array", CharArray2Arb.arb)
val () = probe ("Word8Array2.array", Word8Array2Arb.arb)
val () = probe ("Date.month", DateArb.month)
val () = probe ("Date.weekday", DateArb.weekday)
val () = probe ("IEEEReal.float_class", IEEERealArb.floatClass)
val () = probe ("IEEEReal.decimal_approx", IEEERealArb.decimalApprox)
val () = probe ("StringCvt.radix", BasisDataArb.radix)
val () = probe ("'a VectorSlice.slice", Arb.vectorSlice int)

val () = print ("frozen " ^ StringCvt.padLeft #"0" 16 (Word64.fmt StringCvt.HEX (!observed)) ^ "\n")
val () = if !failed = 0 then () else OS.Process.exit OS.Process.failure
