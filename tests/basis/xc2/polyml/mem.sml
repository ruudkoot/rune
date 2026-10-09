(* What the library takes of Poly/ML's compiler beyond its initial
   environment (prologue.sml), made of Rune's: the casts of
   RunCall.unsafeCast, at the types the patch gives each, and the memory
   operations of RunCall on bytes. *)
structure XC2P =
struct
  (* a word as an int and back, as the bits of a tagged value *)
  val wordToInt : word -> int = Word.toIntX
  val intToWord : int -> word = Word.fromInt
  val charToInt : char -> int = Char.ord
  val intToChar : int -> char = Char.chr
  val charToWord : char -> word = Word.fromInt o Char.ord
  val wordToChar : word -> char = Char.chr o Word.toInt
  val largeToFixed : IntInf.int -> int = IntInf.toInt
  val fixedToLarge : int -> IntInf.int = IntInf.fromInt
  (* a string of one character, which Poly/ML represents by the character *)
  val charToString : char -> string = String.str
  (* RunCall.isShort of a LargeInt.int: whether it is an int *)
  fun largeIsShort (i : IntInf.int) = IntInf.>= (i, IntInf.fromInt (valOf Int.minInt)) andalso IntInf.<= (i, IntInf.fromInt (valOf Int.maxInt))
  (* the name and the message of an exception, which Poly/ML reads from the
     packet (its printer is PolyML.makestring's): Rune's *)
  val exnName = General.exnName
  val exnMessage = General.exnMessage

  (* ---- memory. Poly/ML reads and writes the bytes of a string after its
     length word (the offset of byte i is i + bytesPerWord), and of a byte
     array (an address, Bootstrap.byteArray) and of a byte vector
     (Bootstrap.byteVector) from 0; it allocates a string and fills it
     before it clears its mutable bit. Here an address is an array of
     bytes, a string taken as an address (stringAsAddress), a string being
     made, whose bytes are at the offsets of a string's, and which freeze
     makes a string, or a byte vector, which freezeBytes makes of an array
     of bytes and which, as Poly/ML's, is equal to one of the same bytes. *)
  val wordSize = 8
  datatype address = XC2Bytes of char array | XC2String of string | XC2Building of char array
                   | XC2ByteVector of string
  val str = XC2String
  fun sizeAsWord (s : string) = Word.fromInt (size s)
  fun allocBytes (n : word) = XC2Bytes (Array.array (Word.toInt n, #"\000"))
  fun allocString (n : word) = XC2Building (Array.array (Word.toInt n, #"\000"))
  fun freeze (XC2Building a) = CharVector.tabulate (Array.length a, fn i => Array.sub (a, i))
    | freeze (XC2String s) = s
    | freeze (XC2Bytes a) = CharVector.tabulate (Array.length a, fn i => Array.sub (a, i))
    | freeze (XC2ByteVector s) = s
  fun freezeBytes a = XC2ByteVector (freeze a)
  fun length (XC2Bytes a) = Word.fromInt (Array.length a)
    | length (XC2Building a) = Word.fromInt (Array.length a)
    | length (XC2String s) = Word.fromInt (size s)
    | length (XC2ByteVector s) = Word.fromInt (size s)
  fun loadByte (XC2Bytes a, off : word) = Array.sub (a, Word.toInt off)
    | loadByte (XC2String s, off) = String.sub (s, Word.toInt off - wordSize)
    | loadByte (XC2Building a, off) = Array.sub (a, Word.toInt off - wordSize)
    | loadByte (XC2ByteVector s, off) = String.sub (s, Word.toInt off)
  fun storeByte (XC2Bytes a, off : word, c : char) = Array.update (a, Word.toInt off, c)
    | storeByte (XC2Building a, off, c) = Array.update (a, Word.toInt off - wordSize, c)
    | storeByte (XC2String _, _, _) = raise Fail "xc2: a store into a string"
    | storeByte (XC2ByteVector _, _, _) = raise Fail "xc2: a store into a byte vector"
  fun loadByteW (a, off) = Word.fromInt (Char.ord (loadByte (a, off)))
  fun storeByteW (a, off, w : word) = storeByte (a, off, Char.chr (Word.toInt (Word.andb (w, 0wxFF))))
  (* a byte of a string, at the offset of the string's representation *)
  fun sload (s : string, off : word) = String.sub (s, Word.toInt off - wordSize)
  fun sloadW (s : string, off : word) = Word.fromInt (Char.ord (sload (s, off)))
  (* moveBytes (src, dst, srcOffset, dstOffset, length), which may overlap
     when they are the same array; a string into one being made, the most
     frequent, directly *)
  fun moveBytes (XC2String s, XC2Building a, so : word, dof : word, n : word) =
        let
          val so = Word.toInt so - wordSize and dof = Word.toInt dof - wordSize and n = Word.toInt n
          fun loop k = if k >= n then () else (Array.update (a, dof + k, String.sub (s, so + k)); loop (k + 1))
        in loop 0 end
    | moveBytes (src, dst, so, dof, n) =
        let
          val n = Word.toInt n
          val so = Word.toInt so and dof = Word.toInt dof
          val tmp = CharVector.tabulate (n, fn i => loadByte (src, Word.fromInt (so + i)))
        in CharVector.appi (fn (i, c) => storeByte (dst, Word.fromInt (dof + i), c)) tmp end
  (* a string of part of one, which Poly/ML makes of a new string and a copy *)
  fun substring (s : string, i : word, n : word) = String.substring (s, Word.toInt i, Word.toInt n)
  (* byteVectorCompare and byteVectorEqual of n bytes at the offsets *)
  fun byteVectorCompare (a, b, ao : word, bo : word, n : word) : int =
    let
      fun loop i = if i >= n then 0
                   else case Char.compare (loadByte (a, ao + i), loadByte (b, bo + i)) of
                          EQUAL => loop (i + 0w1) | LESS => ~1 | GREATER => 1
    in loop 0w0 end
  fun byteVectorEqual (a, b, ao, bo, n) = byteVectorCompare (a, b, ao, bo, n) = 0

  (* ---- the bits of a real, as a Word64.word, and of a Real32.real (IEEE
     binary32, in the low 32 bits of a word) *)
  val realToBits = _prim "real_to_bits" : real -> Word64.word
  val bitsToReal = _prim "real_from_bits" : Word64.word -> real
  (* IEEE binary32 from the value, a double that it represents, and back, as
     Rune's packing of a Real32.real works them out (which the shim does not
     use: its file would bring structures that Poly/ML lacks with it) *)
  fun floatToBits (r : Real32.real) : word =
    let
      val x = Real32.toLarge r
      val body =
        if Real.isNan x then 0wx7FC00000
        else if not (Real.isFinite x) then 0wx7F800000
        else if Real.== (x, 0.0) then 0w0
        else
          let val {man, exp} = Real.toManExp (Real.abs x)
          in
            if exp >= ~125 then
              Word.orb (Word.<< (Word.fromInt (exp + 126), 0w23),
                        Word.fromInt (Real.trunc (Real.fromManExp {man = man, exp = 24}) - 8388608))
            else Word.fromInt (Real.trunc (Real.fromManExp {man = Real.abs x, exp = 149}))
          end
    in if Real.signBit x then Word.orb (0wx80000000, body) else body end
  fun floatFromBits (w : word) : Real32.real =
    let
      val e = Word.toInt (Word.andb (Word.>> (w, 0w23), 0wxFF))
      val f = Word.toInt (Word.andb (w, 0wx7FFFFF))
      val a =
        if e = 255 then (if f = 0 then Real.posInf else Real.- (Real.posInf, Real.posInf))
        else if e = 0 then Real.fromManExp {man = Real.fromInt f, exp = ~149}
        else Real.fromManExp {man = Real.fromInt (f + 8388608), exp = e - 150}
      val x = if Word.andb (w, 0wx80000000) = 0w0 then a else Real.~ a
    in Real32.fromLarge IEEEReal.TO_NEAREST x end

  (* the machine's byte order: the family of a socket's address, which is in
     it, is 2 for INET *)
  val bigEndian = Char.ord (String.sub ((_prim "socket_inet_addr" : string * int -> string) ("", 0), 0)) = 0
  (* the 8 bytes of a real as it is in memory (a Poly/ML real is a pointer to
     them) and back *)
  fun realToAddr (r : real) : address =
    let val w = realToBits r
        fun byte k = Char.chr (Word64.toInt (Word64.andb (Word64.>> (w, Word.fromInt (8 * k)), 0wxFF)))
    in XC2Bytes (Array.tabulate (8, fn i => byte (if bigEndian then 7 - i else i))) end
  fun addrToReal (a : address) : real =
    let fun byte i = Word64.fromInt (Char.ord (loadByte (a, Word.fromInt i)))
        fun loop (i, w) = if i = 8 then w
                          else loop (i + 1, Word64.orb (w, Word64.<< (byte i, Word.fromInt (8 * (if bigEndian then 7 - i else i)))))
    in bitsToReal (loop (0, 0w0)) end

  (* ---- a descriptor of Poly/ML's (OS.IO.iodesc, a volatile ref the runtime
     makes, wrapFileDescriptor): the file descriptor plus one, 0 when it is
     closed *)
  datatype iodesc = IODESC of word ref
  fun wrapFd (fd : int) = IODESC (ref (Word.fromInt (fd + 1)))
  fun fdOf (IODESC r) = Word.toIntX (!r) - 1
  fun markClosed (IODESC r) = r := 0w0

  (* Socket.SOCK.sock_type, whose number the runtime takes *)
  datatype sockType = SOCKTYPE of int

  (* ---- vectors of any type: Rune's. Poly/ML allocates one zeroed, fills it
     and clears its mutable bit; one being made here is an array of XC2's,
     whose cells are made at the first update. *)
  fun vlength (v : 'a vector) = Vector.length v
  fun vsub (v : 'a vector, i : int) = Vector.sub (v, i)
  fun vempty () : 'a vector = Vector.fromList []
  val vmaxLen = Vector.maxLen
  fun valloc (n : int) : 'a XC2.array = XC2.Array.alloc n
  fun vset (a : 'a XC2.array, i : int, x : 'a) = XC2.Array.update (a, i, x)
  fun vfreeze (a : 'a XC2.array) = XC2.Array.toVector a
  (* moveWords of n elements from a vector to one being made *)
  fun vcopy (v : 'a vector, a : 'a XC2.array, si : int, di : int, n : int) =
    let fun loop k = if k >= n then () else (vset (a, di + k, vsub (v, si + k)); loop (k + 1))
    in loop 0 end

  (* ---- arrays of any type: Rune's; one made before its elements (an array
     of XC2's) becomes Rune's with afreeze *)
  fun alength (a : 'a array) = Array.length a
  fun asub (a : 'a array, i : int) = Array.sub (a, i)
  fun aupdate (a : 'a array, i : int, x : 'a) = Array.update (a, i, x)
  fun aarray (n : int, x : 'a) : 'a array = Array.array (n, x)
  val amaxLen = Array.maxLen
  fun afreeze (b : 'a XC2.array) : 'a array =
    case b of
      ref (XC2.Cells a) => a
    | ref (XC2.Uninit 0) => Array.fromList []
    | ref (XC2.Uninit _) => raise Fail "xc2: an array none of whose elements was written"
  (* a vector of n elements of an array *)
  fun avector (a : 'a array, start : int, n : int) = Vector.tabulate (n, fn i => Array.sub (a, start + i))
  (* moveWords of n elements to an array, from an array, which may be the
     same, or a vector *)
  fun amove (src : 'a array, dst : 'a array, si : int, di : int, n : int) =
    let
      fun up k = if k >= n then () else (Array.update (dst, di + k, Array.sub (src, si + k)); up (k + 1))
      fun down k = if k < 0 then () else (Array.update (dst, di + k, Array.sub (src, si + k)); down (k - 1))
    in if di > si then down (n - 1) else up 0 end
  fun amoveVec (src : 'a vector, dst : 'a array, si : int, di : int, n : int) =
    let fun up k = if k >= n then () else (Array.update (dst, di + k, Vector.sub (src, si + k)); up (k + 1))
    in up 0 end
end

