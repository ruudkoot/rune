(* The initial environment of Poly/ML's compiler (mlsource/MLCompiler/
   INITIALISE_.ML), in which its library is compiled, made of Rune's: the
   structures Bool, FixedInt, LargeInt, LargeWord, Word, Char, String,
   Real, Real32, RunCall, Bootstrap, Thread and PolyML with the members the
   library uses. FixedInt.int and int are Rune's int and Word.word Rune's
   word, of 63 bits as Poly/ML's; LargeInt.int is IntInf.int, LargeWord.word
   Rune's Word64.word (as Rune's LargeWord, and of 64 bits as Poly/ML's),
   Real32.real Rune's. *)
structure XC2PolyBuiltin =
struct
  structure RunCall =
  struct
    exception Interrupt
    exception Size = Size exception Bind = Bind exception Div = Div exception Match = Match
    exception Overflow = Overflow exception Subscript = Subscript exception Fail = Fail
    exception Conversion of string
    exception XWindows of string
    exception Thread of string
    exception SysErr of string * Word64.word option
    val bytesPerWord : word = 0w8
  end

  structure Bool = struct datatype bool = datatype bool val not = not end

  structure FixedInt =
  struct
    type int = int
    val op < = Int.< val op <= = Int.<= val op > = Int.> val op >= = Int.>=
    val op + = Int.+ val op - = Int.- val op * = Int.*
    val quot = Int.quot val rem = Int.rem
  end

  (* the operations take the runtime's function for the long case, which
     Rune's IntInf does not need *)
  structure LargeInt =
  struct
    type int = IntInf.int
    fun less (i, j, _ : IntInf.int * IntInf.int -> Int.int) = IntInf.< (i, j)
    fun greater (i, j, _ : IntInf.int * IntInf.int -> Int.int) = IntInf.> (i, j)
    fun lessEq (i, j, _ : IntInf.int * IntInf.int -> Int.int) = IntInf.<= (i, j)
    fun greaterEq (i, j, _ : IntInf.int * IntInf.int -> Int.int) = IntInf.>= (i, j)
    fun add (i, j, _ : IntInf.int * IntInf.int -> IntInf.int) = IntInf.+ (i, j)
    fun subtract (i, j, _ : IntInf.int * IntInf.int -> IntInf.int) = IntInf.- (i, j)
    fun multiply (i, j, _ : IntInf.int * IntInf.int -> IntInf.int) = IntInf.* (i, j)
    (* the index of the highest bit set *)
    fun log2Word (w : word) : word = Word.fromInt (IntInf.log2 (IntInf.fromLarge (Word.toLargeInt w)))
  end

  structure LargeWord =
  struct
    type word = Word64.word
    val op < = Word64.< val op <= = Word64.<= val op > = Word64.> val op >= = Word64.>=
    val op + = Word64.+ val op - = Word64.- val op * = Word64.*
    val op div = Word64.div val op mod = Word64.mod
    val orb = Word64.orb val andb = Word64.andb val xorb = Word64.xorb
    val << = Word64.<< val >> = Word64.>> val ~>> = Word64.~>>
  end

  structure Word =
  struct
    type word = word
    val op < = Word.< val op <= = Word.<= val op > = Word.> val op >= = Word.>=
    val op + = Word.+ val op - = Word.- val op * = Word.*
    val op div = Word.div val op mod = Word.mod
    val orb = Word.orb val andb = Word.andb val xorb = Word.xorb
    val << = Word.<< val >> = Word.>> val ~>> = Word.~>>
    val toLargeWord = Word.toLarge
    val toLargeWordX = Word.toLargeX
    val fromLargeWord = Word.fromLarge
  end

  structure Char =
  struct
    type char = char
    val op < = Char.< val op <= = Char.<= val op > = Char.> val op >= = Char.>=
  end

  structure String = struct type string = string end

  structure Real =
  struct
    type real = real
    val op < = Real.< val op <= = Real.<= val op > = Real.> val op >= = Real.>=
    val == = Real.== val unordered = Real.unordered
    val op + = Real.+ val op - = Real.- val op * = Real.* val op / = Real./
    val ~ = Real.~ val abs = Real.abs
    val fromFixedInt = Real.fromInt
    val truncFix = Real.trunc val roundFix = Real.round val ceilFix = Real.ceil val floorFix = Real.floor
  end

  structure Real32 =
  struct
    type real = Real32.real
    val op < = Real32.< val op <= = Real32.<= val op > = Real32.> val op >= = Real32.>=
    val == = Real32.== val unordered = Real32.unordered
    val op + = Real32.+ val op - = Real32.- val op * = Real32.* val op / = Real32./
    val ~ = Real32.~ val abs = Real32.abs
    val fromFixedInt = Real32.fromInt
    val truncFix = Real32.trunc val roundFix = Real32.round val ceilFix = Real32.ceil val floorFix = Real32.floor
    fun toLarge (r : real) : Real.real = Real32.toLarge r
    (* in the rounding mode of the moment, as the machine's conversion is *)
    fun fromReal (r : Real.real) : real = Real32.fromLarge (IEEEReal.getRoundingMode ()) r
  end

  structure Thread =
  struct
    (* one thread, whose mutexes are never contended *)
    datatype thread = XC2PolyThread
    fun self () = XC2PolyThread
    fun createMutex () : word ref = ref 0w0
    fun lockMutex (m : word ref) = (m := 0w1; true)
    fun tryLockMutex (m : word ref) = if !m = 0w0 then (m := 0w1; true) else false
    fun unlockMutex (m : word ref) = (m := 0w0; true)
    fun cpuPause () = ()
  end

  structure Bootstrap =
  struct
    val intIsArbitraryPrecision = false
    (* a vector and an array of bytes: the addresses of LibrarySupport *)
    type byteVector = XC2P.address
    type byteArray = XC2P.address
    (* Array2's array, an equality type for any element with the equality of
       a pointer: a ref of its rows *)
    type 'a array = 'a Array.array Vector.vector ref
  end

  structure PolyML =
  struct
    type location = {file : string, startLine : int, startPosition : int, endLine : int, endPosition : int}
    datatype context = ContextLocation of location | ContextProperty of string * string
    datatype pretty = PrettyBlock of int * bool * context list * pretty list
                    | PrettyBreak of int * int
                    | PrettyLineBreak
                    | PrettyString of string
                    | PrettyStringWithWidth of string * int
    (* the printers of the top level, which the suite does not use *)
    fun addPrettyPrinter (_ : int -> 'a -> 'b -> pretty) = ()
    fun prettyRepresentation (_ : 'a, _ : int) = PrettyString "?"
  end
end

