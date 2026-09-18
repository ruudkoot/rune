(* requires: Byte Word8 Word8Vector *)
(* The Byte structure (signature BYTE). Expected values follow the text of
   https://smlfamily.github.io/Basis/byte.html. Bytes are written as ints:
   vec [104, 105] is the vector of the bytes 104 and 105. *)
structure TestByte =
struct
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqI = T.eq T.int
  val eqV = T.eq (T.list T.int)

  fun vec (l : int list) : Word8Vector.vector = Word8Vector.fromList (List.map Word8.fromInt l)
  fun ints (v : Word8Vector.vector) : int list = Word8Vector.foldr (fn (w, l) => Word8.toInt w :: l) [] v
  fun allChars () = String.implode (List.tabulate (256, Char.chr))
  fun randomString (n : int) : string = String.implode (List.tabulate (n, fn _ => Char.chr (T.range (0, 255))))

  (* ==== bytesToString, stringToBytes ====
     "These functions convert between a vector of character codes and the
     corresponding string. Note that these functions do not perform
     end-of-line, or other character, translations." *)
  val () = eqS ("Byte.bytesToString/basic", "hi!", fn () => Byte.bytesToString (vec [104, 105, 33]))
  val () = eqS ("Byte.bytesToString/empty", "", fn () => Byte.bytesToString (vec []))
  val () = eqS ("Byte.bytesToString/one", "A", fn () => Byte.bytesToString (vec [65]))
  val () = eqS ("Byte.bytesToString/no-translation", "\r\n\000\026\255\n\r", fn () => Byte.bytesToString (vec [13, 10, 0, 26, 255, 10, 13]))
  val () = eqB ("Byte.bytesToString/every-byte", true, fn () => Byte.bytesToString (vec (List.tabulate (256, fn i => i))) = allChars ())
  val () = eqI ("Byte.bytesToString/size", 1000,
                fn () => String.size (Byte.bytesToString (Word8Vector.tabulate (1000, fn i => Word8.fromInt (i mod 256)))))

  val () = eqV ("Byte.stringToBytes/basic", [104, 105, 33], fn () => ints (Byte.stringToBytes "hi!"))
  val () = eqV ("Byte.stringToBytes/empty", [], fn () => ints (Byte.stringToBytes ""))
  val () = eqV ("Byte.stringToBytes/one", [65], fn () => ints (Byte.stringToBytes "A"))
  val () = eqV ("Byte.stringToBytes/no-translation", [13, 10, 0, 26, 255, 10, 13], fn () => ints (Byte.stringToBytes "\r\n\000\026\255\n\r"))
  val () = eqV ("Byte.stringToBytes/every-character", List.tabulate (256, fn i => i), fn () => ints (Byte.stringToBytes (allChars ())))
  val () = eqI ("Byte.stringToBytes/length", 1000,
                fn () => Word8Vector.length (Byte.stringToBytes (String.implode (List.tabulate (1000, fn i => Char.chr (i mod 256))))))

  (* The definitions the page gives: element i of the one is the code of
     element i of the other; so each function inverts the other. *)
  val () = T.seed 606
  val () = T.repeat (10, fn i =>
             eqB ("Byte.stringToBytes/random-elementwise-" ^ Int.toString i, true,
                  fn () => let val s = randomString (T.range (0, 500)) val v = Byte.stringToBytes s
                           in
                             Word8Vector.length v = String.size s
                             andalso ints v = List.map Char.ord (String.explode s)
                           end))
  val () = T.repeat (10, fn i =>
             eqB ("Byte.bytesToString/random-inverts-stringToBytes-" ^ Int.toString i, true,
                  fn () => let val s = randomString (T.range (0, 500)) in Byte.bytesToString (Byte.stringToBytes s) = s end))
  val () = T.repeat (10, fn i =>
             eqB ("Byte.stringToBytes/random-inverts-bytesToString-" ^ Int.toString i, true,
                  fn () => let val v = vec (List.tabulate (T.range (0, 500), fn _ => T.range (0, 255)))
                           in Byte.stringToBytes (Byte.bytesToString v) = v end))

  (*<< bytechar *)
  (* "returns the character whose code is i"; "returns an 8-bit word holding
     the code for the character c" *)
  val () = T.eq T.char ("Byte.byteToChar/basic", #"A", fn () => Byte.byteToChar (Word8.fromInt 65))
  val () = T.eq T.char ("Byte.byteToChar/zero", #"\000", fn () => Byte.byteToChar (Word8.fromInt 0))
  val () = T.eq T.char ("Byte.byteToChar/255", #"\255", fn () => Byte.byteToChar (Word8.fromInt 255))
  val () = T.eq T.char ("Byte.byteToChar/newline", #"\n", fn () => Byte.byteToChar (Word8.fromInt 10))
  val () = eqB ("Byte.byteToChar/every-byte", true,
                fn () => List.tabulate (256, fn i => Byte.byteToChar (Word8.fromInt i)) = List.tabulate (256, Char.chr))
  val () = eqI ("Byte.charToByte/basic", 65, fn () => Word8.toInt (Byte.charToByte #"A"))
  val () = eqI ("Byte.charToByte/zero", 0, fn () => Word8.toInt (Byte.charToByte #"\000"))
  val () = eqI ("Byte.charToByte/255", 255, fn () => Word8.toInt (Byte.charToByte #"\255"))
  val () = eqI ("Byte.charToByte/newline", 10, fn () => Word8.toInt (Byte.charToByte #"\n"))
  val () = eqB ("Byte.charToByte/every-character", true,
                fn () => List.tabulate (256, fn i => Word8.toInt (Byte.charToByte (Char.chr i))) = List.tabulate (256, fn i => i))
  val () = eqB ("Byte.charToByte/inverts-byteToChar", true,
                fn () => List.all (fn i => Byte.charToByte (Byte.byteToChar (Word8.fromInt i)) = Word8.fromInt i)
                                  (List.tabulate (256, fn i => i)))
  val () = eqB ("Byte.byteToChar/inverts-charToByte", true,
                fn () => List.all (fn i => Byte.byteToChar (Byte.charToByte (Char.chr i)) = Char.chr i)
                                  (List.tabulate (256, fn i => i)))
  (* A byte above 127 is the character with that code, not a negative one. *)
  val () = eqI ("Byte.byteToChar/high-bytes-are-not-negative", 200, fn () => Char.ord (Byte.byteToChar (Word8.fromInt 200)))
  (*>> bytechar *)

  (*<< unpackStringVec *)
  (* "returns the string consisting of characters whose codes are held in the
     vector slice slice" *)
  val hello = fn () => vec [104, 101, 108, 108, 111]
  val () = eqS ("Byte.unpackStringVec/full", "hello", fn () => Byte.unpackStringVec (Word8VectorSlice.full (hello ())))
  val () = eqS ("Byte.unpackStringVec/middle", "ell", fn () => Byte.unpackStringVec (Word8VectorSlice.slice (hello (), 1, SOME 3)))
  val () = eqS ("Byte.unpackStringVec/to-the-end", "llo", fn () => Byte.unpackStringVec (Word8VectorSlice.slice (hello (), 2, NONE)))
  val () = eqS ("Byte.unpackStringVec/first", "h", fn () => Byte.unpackStringVec (Word8VectorSlice.slice (hello (), 0, SOME 1)))
  val () = eqS ("Byte.unpackStringVec/last", "o", fn () => Byte.unpackStringVec (Word8VectorSlice.slice (hello (), 4, SOME 1)))
  val () = eqS ("Byte.unpackStringVec/empty-slice", "", fn () => Byte.unpackStringVec (Word8VectorSlice.slice (hello (), 2, SOME 0)))
  val () = eqS ("Byte.unpackStringVec/empty-slice-at-the-end", "", fn () => Byte.unpackStringVec (Word8VectorSlice.slice (hello (), 5, NONE)))
  val () = eqS ("Byte.unpackStringVec/empty-vector", "", fn () => Byte.unpackStringVec (Word8VectorSlice.full (vec [])))
  val () = eqS ("Byte.unpackStringVec/no-translation", "\r\n\000\255",
                fn () => Byte.unpackStringVec (Word8VectorSlice.slice (vec [1, 13, 10, 0, 255, 2], 1, SOME 4)))
  val () = eqS ("Byte.unpackStringVec/slice-of-a-slice", "l",
                fn () => Byte.unpackStringVec (Word8VectorSlice.subslice (Word8VectorSlice.slice (hello (), 1, SOME 3), 1, SOME 1)))
  val () = T.repeat (10, fn i =>
             eqB ("Byte.unpackStringVec/random-" ^ Int.toString i, true,
                  fn () => let
                             val s = randomString (T.range (0, 300))
                             val start = T.range (0, String.size s)
                             val len = T.range (0, String.size s - start)
                           in
                             Byte.unpackStringVec (Word8VectorSlice.slice (Byte.stringToBytes s, start, SOME len))
                             = String.substring (s, start, len)
                           end))
  (*>> unpackStringVec *)

  (*<< unpackString *)
  (* "returns the string consisting of characters whose codes are held in the
     array slice slice" *)
  fun arr (l : int list) : Word8Array.array = Word8Array.fromList (List.map Word8.fromInt l)
  val helloA = fn () => arr [104, 101, 108, 108, 111]
  val () = eqS ("Byte.unpackString/full", "hello", fn () => Byte.unpackString (Word8ArraySlice.full (helloA ())))
  val () = eqS ("Byte.unpackString/middle", "ell", fn () => Byte.unpackString (Word8ArraySlice.slice (helloA (), 1, SOME 3)))
  val () = eqS ("Byte.unpackString/to-the-end", "llo", fn () => Byte.unpackString (Word8ArraySlice.slice (helloA (), 2, NONE)))
  val () = eqS ("Byte.unpackString/empty-slice", "", fn () => Byte.unpackString (Word8ArraySlice.slice (helloA (), 2, SOME 0)))
  val () = eqS ("Byte.unpackString/empty-slice-at-the-end", "", fn () => Byte.unpackString (Word8ArraySlice.slice (helloA (), 5, NONE)))
  val () = eqS ("Byte.unpackString/empty-array", "", fn () => Byte.unpackString (Word8ArraySlice.full (arr [])))
  val () = eqS ("Byte.unpackString/no-translation", "\r\n\000\255",
                fn () => Byte.unpackString (Word8ArraySlice.slice (arr [1, 13, 10, 0, 255, 2], 1, SOME 4)))
  (* The slice is read when unpackString is called: the array as it is then. *)
  val () = T.eq (T.pair (T.string, T.string)) ("Byte.unpackString/sees-the-current-contents", ("hello", "jello"),
                fn () => let
                           val a = helloA ()
                           val sl = Word8ArraySlice.full a
                           val first = Byte.unpackString sl
                           val () = Word8Array.update (a, 0, Word8.fromInt 106)
                         in
                           (first, Byte.unpackString sl)
                         end)
  val () = T.repeat (10, fn i =>
             eqB ("Byte.unpackString/random-" ^ Int.toString i, true,
                  fn () => let
                             val s = randomString (T.range (0, 300))
                             val start = T.range (0, String.size s)
                             val len = T.range (0, String.size s - start)
                             val a = Word8Array.tabulate (String.size s, fn k => Word8.fromInt (Char.ord (String.sub (s, k))))
                           in
                             Byte.unpackString (Word8ArraySlice.slice (a, start, SOME len)) = String.substring (s, start, len)
                           end))
  (*>> unpackString *)

  (*<< packString *)
  (* "puts the substring s into the array arr starting at offset i. It raises
     Subscript if i < 0 or size s + i > |arr|." *)
  fun zeros (n : int) : Word8Array.array = Word8Array.array (n, Word8.fromInt 0)
  fun contents (a : Word8Array.array) : int list = Word8Array.foldr (fn (w, l) => Word8.toInt w :: l) [] a
  fun packed (n : int, i : int, ss : substring) : int list =
    let val a = zeros n in Byte.packString (a, i, ss); contents a end
  val () = eqV ("Byte.packString/at-the-start", [104, 105, 0, 0, 0], fn () => packed (5, 0, Substring.full "hi"))
  val () = eqV ("Byte.packString/in-the-middle", [0, 0, 104, 105, 0], fn () => packed (5, 2, Substring.full "hi"))
  val () = eqV ("Byte.packString/up-to-the-end", [0, 0, 0, 104, 105], fn () => packed (5, 3, Substring.full "hi"))
  val () = eqV ("Byte.packString/whole-array", [104, 101, 108, 108, 111], fn () => packed (5, 0, Substring.full "hello"))
  val () = eqV ("Byte.packString/part-of-a-string", [0, 119, 111, 114, 0],
                fn () => packed (5, 1, Substring.substring ("hello world", 6, 3)))
  val () = eqV ("Byte.packString/empty-substring", [0, 0, 0], fn () => packed (3, 1, Substring.full ""))
  val () = eqV ("Byte.packString/empty-substring-at-the-end", [0, 0, 0], fn () => packed (3, 3, Substring.substring ("abc", 1, 0)))
  val () = eqV ("Byte.packString/empty-array", [], fn () => packed (0, 0, Substring.full ""))
  val () = eqV ("Byte.packString/no-translation", [13, 10, 0, 255], fn () => packed (4, 0, Substring.full "\r\n\000\255"))
  val () = eqV ("Byte.packString/keeps-the-other-elements", [9, 97, 98, 9],
                fn () => let val a = Word8Array.array (4, Word8.fromInt 9)
                         in Byte.packString (a, 1, Substring.full "ab"); contents a end)
  val () = eqV ("Byte.packString/twice", [97, 120, 121, 0],
                fn () => let val a = zeros 4
                         in Byte.packString (a, 0, Substring.full "ab"); Byte.packString (a, 1, Substring.full "xy"); contents a end)
  val () = T.raises ("Byte.packString/Subscript-negative-offset", T.isSubscript, fn () => packed (5, ~1, Substring.full "hi"))
  val () = T.raises ("Byte.packString/Subscript-negative-offset-empty-substring", T.isSubscript,
                     fn () => packed (5, ~1, Substring.full ""))
  val () = T.raises ("Byte.packString/Subscript-one-too-long", T.isSubscript, fn () => packed (5, 4, Substring.full "hi"))
  val () = T.raises ("Byte.packString/Subscript-offset-is-the-length", T.isSubscript, fn () => packed (5, 5, Substring.full "h"))
  val () = T.raises ("Byte.packString/Subscript-offset-beyond-the-length-empty-substring", T.isSubscript, fn () => packed (5, 6, Substring.full ""))
  val () = T.raises ("Byte.packString/Subscript-longer-than-the-array", T.isSubscript, fn () => packed (3, 0, Substring.full "hello"))
  val () = T.raises ("Byte.packString/Subscript-empty-array", T.isSubscript, fn () => packed (0, 0, Substring.full "h"))
  val () = T.repeat (10, fn i =>
             eqB ("Byte.packString/random-" ^ Int.toString i, true,
                  fn () => let
                             val s = randomString (T.range (0, 300))
                             val start = T.range (0, String.size s)
                             val len = T.range (0, String.size s - start)
                             val offset = T.range (0, 20)
                             val n = offset + len + T.range (0, 20)
                             val a = Word8Array.array (n, Word8.fromInt 7)
                             val () = Byte.packString (a, offset, Substring.substring (s, start, len))
                           in
                             contents a = List.tabulate (n, fn k => if k >= offset andalso k < offset + len
                                                                    then Char.ord (String.sub (s, start + k - offset)) else 7)
                           end))
  (*>> packString *)
end
