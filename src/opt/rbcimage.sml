(* The program in an image (vm/image.c), as an .rbc: what runeopt --from-image
   translates, so that the executable resumes the image (docs/native.md,
   Images). An image carries its program whole --
   constants, functions, code, files and line table -- after the heap, from
   which the string constants are taken; what comes after the program, the
   state of the world, is not read.

   A real constant is 64 bits in an image and text in an .rbc. It is written
   as C's hexadecimal notation, which strtod reads back to the same bits and
   which is worked out here from the bits with integers alone: the tool never
   turns a real into a number (the portability rules of docs/building.md). *)
structure RbcImage =
struct
  exception Bad of string

  fun fail msg = raise Bad msg

  (* IMAGE_MAGIC of vm/image.c, with the fingerprint of the instruction set *)
  val magic = "runevm image 4 isa " ^ Opcodes.fingerprintHex ^ "\000"
  val big = Rbc.big

  type reader = {data : string, pos : int ref}

  fun need ({data, pos} : reader, n) =
    if n < 0 orelse n > String.size data - !pos then fail "the image is cut short" else ()

  fun byte ({data, pos} : reader) = Char.ord (String.sub (data, !pos)) before pos := !pos + 1

  fun uN (r, n) : IntInf.int =
    let
      val () = need (r, n)
      val p = !(#pos r)
      fun go (k, acc) =
        if k < 0 then acc
        else go (k - 1, IntInf.+ (IntInf.* (acc, IntInf.fromInt 256),
                                  IntInf.fromInt (Char.ord (String.sub (#data r, p + k)))))
    in
      #pos r := p + n;
      go (n - 1, IntInf.fromInt 0)
    end

  (* a number that has to fit an int: a count, a length, an offset *)
  fun small (r, n) : int =
    let val v = uN (r, n)
    in if IntInf.> (v, IntInf.fromInt big) then fail "a number of the image is too large" else IntInf.toInt v end

  fun u8 r = small (r, 1)
  fun u16 r = small (r, 2)
  fun u32 r = small (r, 4)
  fun u64 r = small (r, 8)

  fun take (r as {data, pos} : reader, n) =
    (need (r, n); String.substring (data, !pos, n) before pos := !pos + n)

  fun str r = take (r, u64 r)

  (* A value: its tag and its 8 bytes. *)
  fun value r = (u8 r, uN (r, 8))

  val kString = 4                         (* K_STRING of vm/vm.h *)
  val tInt = 1 val tWord = 2 val tReal = 3 val tChar = 4 val tPtr = 6

  fun payloadSize bytes = let val s = (bytes + 15) div 16 * 16 in if s < 16 then 16 else s end

  (* The heap: the strings, by their offset from its start. *)
  fun heap (r, used) : string IntMap.map =
    let
      fun go (at, acc) =
        if at >= used then acc
        else
          let
            val kind = u8 r
            val _ = u16 r
            val len = u32 r
            val () = if len > big div 16 then fail "an object of the image is too large" else ()
            val (acc, payload) =
              if kind = kString then (IntMap.insert (acc, at, take (r, len)), len)
              else (ignore (take (r, 9 * len)); (acc, 16 * len))
          in
            go (at + 8 + payloadSize payload, acc)
          end
    in
      go (0, IntMap.empty)
    end

  val two = IntInf.fromInt 2
  fun pow2 n = IntInf.pow (two, n)

  (* The bits of a double as C reads them back: 0x1.<52 bits>p<exponent>,
     0x0.<52 bits>p-1022 below the normal numbers, inf and nan. *)
  fun realText (bits : IntInf.int) : string =
    let
      val negative = IntInf.>= (bits, pow2 63)
      val b = if negative then IntInf.- (bits, pow2 63) else bits
      val exponent = IntInf.toInt (IntInf.div (b, pow2 52))
      val mantissa = IntInf.mod (b, pow2 52)
      val sign = if negative then "-" else ""
      val hex = StringCvt.padLeft #"0" 13 (String.map Char.toLower (IntInf.fmt StringCvt.HEX mantissa))
    in
      if exponent = 2047 then (if IntInf.compare (mantissa, IntInf.fromInt 0) = EQUAL then sign ^ "inf" else "nan")
      else if exponent = 0 then sign ^ "0x0." ^ hex ^ "p-1022"
      else sign ^ "0x1." ^ hex ^ "p" ^ Rbc.minus (Int.toString (exponent - 1023))
    end

  (* The .rbc of the program of an image, whose bytes are given. *)
  fun toRbc (data : string) : string =
    let
      val r = {data = data, pos = ref 0} : reader
      val () = if String.size data >= String.size magic andalso String.substring (data, 0, String.size magic) = magic
               then #pos r := String.size magic else fail "not an image of this runevm"
      val _ = u32 r                                   (* the kind *)
      val () = List.app (fn _ => ignore (u32 r)) [1, 2, 3, 4, 5, 6]
      val () = List.app (fn _ => ignore (uN (r, 8))) [1, 2, 3, 4, 5, 6, 7]
      val _ = u32 r                                   (* pc *)
      val _ = u32 r                                   (* io_errno *)
      val _ = str r                                   (* progname *)
      val argc = u32 r
      fun skip 0 = () | skip n = (ignore (str r); skip (n - 1))
      val () = skip argc
      val _ = uN (r, 8)                               (* heap_size *)
      val used = u64 r
      val strings = heap (r, used)
      fun stringAt off =
        case IntMap.find (strings, off) of
          SOME s => s
        | NONE => fail "a constant is not a string of the heap"
      val nconsts = u32 r
      fun consts (0, acc) = List.rev acc
        | consts (n, acc) =
            let
              val (tag, w) = value r
              val c =
                if tag = tInt then Rbc.CInt (Rbc.signed64 w)
                else if tag = tWord then Rbc.CWord w
                else if tag = tReal then Rbc.CReal (realText w)
                else if tag = tChar then Rbc.CChar (IntInf.toInt w)
                else if tag = tPtr then Rbc.CString (stringAt (IntInf.toInt w))
                else fail "a constant of a kind no .rbc has"
            in
              consts (n - 1, c :: acc)
            end
      val cs = consts (nconsts, [])
      val nglobals = u32 r
      val nfuncs = u32 r
      fun funcs (0, acc) = List.rev acc
        | funcs (n, acc) =
            let val offset = u32 r val _ = u32 r val nlocals = u32 r val name = str r
            in funcs (n - 1, (offset, nlocals, name) :: acc) end
      val fs = funcs (nfuncs, [])
      val code = take (r, u32 r)
      val nfiles = u32 r
      fun files (0, acc) = List.rev acc
        | files (n, acc) = files (n - 1, str r :: acc)
      val fls = files (nfiles, [])
      val nlines = u32 r
      fun lines (0, acc) = List.rev acc
        | lines (n, acc) =
            let val pc = u32 r val file = u32 r val line = u32 r val col = u32 r
            in lines (n - 1, (pc, file, line, col) :: acc) end
      val ls = lines (nlines, [])
    in
      Rbc.write {consts = cs, nglobals = nglobals, funcs = fs, code = code, files = fls, lines = ls}
    end

  fun readFile (path : string) : string =
    let
      val ins = BinIO.openIn path handle IO.Io _ => fail "cannot open the image"
      val data = Byte.bytesToString (BinIO.inputAll ins)
    in
      BinIO.closeIn ins;
      toRbc data
    end
end
