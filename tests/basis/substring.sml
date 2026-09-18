(* requires: Substring *)
(* The Substring structure (signature SUBSTRING), for 8-bit characters.
   Expected values follow the text of
   https://smlfamily.github.io/Basis/substring.html.

   "A substring value can be modeled as a triple (s, i, n), where s is the
   underlying string, i is the starting index, and n is the size of the
   substring", and "We require that base o substring be the identity function
   on valid arguments": so a result is compared through base, as such a
   triple, which checks its position in the underlying string as well as its
   characters ("Functions that extract pieces of a substring, such as splitl or
   tokens must return substrings with the same base string").

   Where the page leaves the position of an empty result open (triml k and
   trimr k with k beyond the size: "an empty substring is returned"), only
   the size and the underlying string are checked, and that the result lies
   within the argument.

   Size (concat, concatWith) needs substrings whose sizes add up to more than
   String.maxSize. They can share one string, but an implementation that
   forgets the check would build the result: it is checked only where
   String.maxSize is at most 2^26. *)
structure TestSubstring =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqOrd = T.eq T.order
  val eqCL = T.eq (T.list T.char)
  val eqCO = T.eq (T.option T.char)
  val showT = T.triple (T.string, T.int, T.int)
  val eqT = T.eq showT
  val eqTT = T.eq (T.pair (showT, showT))
  val eqTL = T.eq (T.list showT)
  val eqG = T.eq (T.option (T.pair (T.char, showT)))

  fun base2 (a, b) = (Substring.base a, Substring.base b)
  fun bases l = List.map Substring.base l

  (* trace f: f, and the characters it has been applied to so far, in order. *)
  fun trace (f : char -> 'a) : (char -> 'a) * (unit -> char list) =
    let val log = ref []
    in (fn c => (log := c :: !log; f c), fn () => List.rev (!log)) end

  fun fromTo (lo, hi) = if lo > hi then [] else lo :: fromTo (lo + 1, hi)
  fun isBar c = c = #"|"
  fun isA c = c = #"a"
  fun notX c = c <> #"X"

  (* the smallest and the largest int, or a small and a large one *)
  val big = case Int.maxInt of SOME m => m | NONE => 1073741823
  val small = case Int.minInt of SOME m => m | NONE => ~1073741824

  val s8 = "abcdefgh"
  (* "cdef", in the middle of s8 *)
  fun mid () = Substring.substring (s8, 2, 4)
  (* an empty substring in the middle of s8 *)
  fun nothing () = Substring.substring (s8, 3, 0)

  (* subscript f: f () raises Subscript *)
  fun subscript (f : unit -> 'a) : bool = (ignore (f ()); false) handle Subscript => true | _ => false

  (* ---- substring, base ----
     "returns the substring s[i..i+j-1], i.e., the substring of size j starting
     at index i"; "We require that base o substring be the identity function on
     valid arguments." *)
  val () = eqT ("Substring.substring/middle", ("abcde", 1, 3), fn () => Substring.base (Substring.substring ("abcde", 1, 3)))
  val () = eqT ("Substring.substring/whole", ("abcde", 0, 5), fn () => Substring.base (Substring.substring ("abcde", 0, 5)))
  val () = eqT ("Substring.substring/to-the-end", ("abcde", 3, 2), fn () => Substring.base (Substring.substring ("abcde", 3, 2)))
  val () = eqT ("Substring.substring/zero-at-start", ("abcde", 0, 0), fn () => Substring.base (Substring.substring ("abcde", 0, 0)))
  val () = eqT ("Substring.substring/zero-inside", ("abcde", 2, 0), fn () => Substring.base (Substring.substring ("abcde", 2, 0)))
  val () = eqT ("Substring.substring/zero-at-size", ("abcde", 5, 0), fn () => Substring.base (Substring.substring ("abcde", 5, 0)))
  val () = eqT ("Substring.substring/empty-string", ("", 0, 0), fn () => Substring.base (Substring.substring ("", 0, 0)))
  val () = eqS ("Substring.substring/string-middle", "bcd", fn () => Substring.string (Substring.substring ("abcde", 1, 3)))
  val () = eqS ("Substring.substring/string-zero", "", fn () => Substring.string (Substring.substring ("abcde", 2, 0)))
  val () = eqT ("Substring.base/basic", (s8, 2, 4), fn () => Substring.base (mid ()))
  val () = eqT ("Substring.base/empty", (s8, 3, 0), fn () => Substring.base (nothing ()))
  (* every valid (i, j) for a string of size 5 *)
  val () = eqI ("Substring.base/identity-on-every-valid-argument", 0,
                fn () => List.length (List.filter (fn (i, j) => Substring.base (Substring.substring ("abcde", i, j)) <> ("abcde", i, j))
                           (List.concat (List.map (fn i => List.map (fn j => (i, j)) (fromTo (0, 5 - i))) (fromTo (0, 5))))))
  (* "It raises Subscript if i < 0 or j < 0 or |s| < i + j." *)
  val () = T.raises ("Substring.substring/Subscript-too-long", T.isSubscript, fn () => Substring.substring ("abcde", 0, 6))
  val () = T.raises ("Substring.substring/Subscript-end-beyond-size", T.isSubscript, fn () => Substring.substring ("abcde", 3, 3))
  val () = T.raises ("Substring.substring/Subscript-start-beyond-size", T.isSubscript, fn () => Substring.substring ("abcde", 6, 0))
  val () = T.raises ("Substring.substring/Subscript-negative-start", T.isSubscript, fn () => Substring.substring ("abcde", ~1, 1))
  val () = T.raises ("Substring.substring/Subscript-negative-start-zero-size", T.isSubscript, fn () => Substring.substring ("abcde", ~1, 0))
  val () = T.raises ("Substring.substring/Subscript-negative-size", T.isSubscript, fn () => Substring.substring ("abcde", 1, ~1))
  val () = T.raises ("Substring.substring/Subscript-negative-size-at-size", T.isSubscript, fn () => Substring.substring ("abcde", 5, ~1))
  (* i + j is within the string, but j < 0 *)
  val () = T.raises ("Substring.substring/Subscript-negative-size-end-inside", T.isSubscript, fn () => Substring.substring ("abcde", 4, ~2))
  val () = T.raises ("Substring.substring/Subscript-both-negative", T.isSubscript, fn () => Substring.substring ("abcde", ~1, ~1))
  val () = T.raises ("Substring.substring/Subscript-empty-string-size", T.isSubscript, fn () => Substring.substring ("", 0, 1))
  val () = T.raises ("Substring.substring/Subscript-empty-string-start", T.isSubscript, fn () => Substring.substring ("", 1, 0))
  (* every invalid (i, j) with ~2 <= i, j <= 7 *)
  val () = eqI ("Substring.substring/Subscript-on-every-invalid-argument", 0,
                fn () => List.length (List.filter (fn (i, j) => (i < 0 orelse j < 0 orelse 5 < i + j)
                                                                andalso not (subscript (fn () => Substring.substring ("abcde", i, j))))
                           (List.concat (List.map (fn i => List.map (fn j => (i, j)) (fromTo (~2, 7))) (fromTo (~2, 7))))))

  (* ---- extract ----
     (s, i, NONE): "the substring of s from the i(th) character to the end of
     the string ... This raises Subscript unless 0 <= i <= |s|." *)
  val () = eqT ("Substring.extract/NONE-whole", ("abcde", 0, 5), fn () => Substring.base (Substring.extract ("abcde", 0, NONE)))
  val () = eqT ("Substring.extract/NONE-middle", ("abcde", 2, 3), fn () => Substring.base (Substring.extract ("abcde", 2, NONE)))
  val () = eqT ("Substring.extract/NONE-last", ("abcde", 4, 1), fn () => Substring.base (Substring.extract ("abcde", 4, NONE)))
  (* "Note that, if defined, extract returns the empty substring when i = |s|." *)
  val () = eqT ("Substring.extract/NONE-at-size", ("abcde", 5, 0), fn () => Substring.base (Substring.extract ("abcde", 5, NONE)))
  val () = eqT ("Substring.extract/NONE-empty-string", ("", 0, 0), fn () => Substring.base (Substring.extract ("", 0, NONE)))
  val () = eqS ("Substring.extract/NONE-string", "cde", fn () => Substring.string (Substring.extract ("abcde", 2, NONE)))
  val () = T.raises ("Substring.extract/NONE-Subscript-beyond-size", T.isSubscript, fn () => Substring.extract ("abcde", 6, NONE))
  val () = T.raises ("Substring.extract/NONE-Subscript-negative", T.isSubscript, fn () => Substring.extract ("abcde", ~1, NONE))
  val () = T.raises ("Substring.extract/NONE-Subscript-empty-string", T.isSubscript, fn () => Substring.extract ("", 1, NONE))
  (* (s, i, SOME j): "the substring of size j starting at index i ... It raises
     Subscript if i < 0 or j < 0 or |s| < i + j." *)
  val () = eqT ("Substring.extract/SOME-middle", ("abcde", 1, 3), fn () => Substring.base (Substring.extract ("abcde", 1, SOME 3)))
  val () = eqT ("Substring.extract/SOME-whole", ("abcde", 0, 5), fn () => Substring.base (Substring.extract ("abcde", 0, SOME 5)))
  val () = eqT ("Substring.extract/SOME-zero-inside", ("abcde", 2, 0), fn () => Substring.base (Substring.extract ("abcde", 2, SOME 0)))
  val () = eqT ("Substring.extract/SOME-zero-at-size", ("abcde", 5, 0), fn () => Substring.base (Substring.extract ("abcde", 5, SOME 0)))
  val () = eqT ("Substring.extract/SOME-empty-string", ("", 0, 0), fn () => Substring.base (Substring.extract ("", 0, SOME 0)))
  val () = eqS ("Substring.extract/SOME-string", "bcd", fn () => Substring.string (Substring.extract ("abcde", 1, SOME 3)))
  val () = T.raises ("Substring.extract/SOME-Subscript-too-long", T.isSubscript, fn () => Substring.extract ("abcde", 0, SOME 6))
  val () = T.raises ("Substring.extract/SOME-Subscript-end-beyond-size", T.isSubscript, fn () => Substring.extract ("abcde", 3, SOME 3))
  val () = T.raises ("Substring.extract/SOME-Subscript-start-beyond-size", T.isSubscript, fn () => Substring.extract ("abcde", 6, SOME 0))
  val () = T.raises ("Substring.extract/SOME-Subscript-negative-start", T.isSubscript, fn () => Substring.extract ("abcde", ~1, SOME 1))
  val () = T.raises ("Substring.extract/SOME-Subscript-negative-size", T.isSubscript, fn () => Substring.extract ("abcde", 1, SOME ~1))
  val () = T.raises ("Substring.extract/SOME-Subscript-negative-size-end-inside", T.isSubscript, fn () => Substring.extract ("abcde", 4, SOME ~2))
  (* substring (s, i, j) "is equivalent to extract(s, i, SOME j)": the same
     result or Subscript, for ~2 <= i, j <= 7 *)
  val () = eqI ("Substring.extract/SOME-is-substring", 0,
                fn () => List.length (List.filter (fn (i, j) =>
                             let fun outcome f = SOME (Substring.base (f ())) handle Subscript => NONE
                             in outcome (fn () => Substring.extract ("abcde", i, SOME j))
                                <> outcome (fn () => Substring.substring ("abcde", i, j)) end)
                           (List.concat (List.map (fn i => List.map (fn j => (i, j)) (fromTo (~2, 7))) (fromTo (~2, 7))))))
  val () = eqI ("Substring.extract/NONE-every-argument", 0,
                fn () => List.length (List.filter (fn i =>
                             (SOME (Substring.base (Substring.extract ("abcde", i, NONE))) handle Subscript => NONE)
                             <> (if 0 <= i andalso i <= 5 then SOME ("abcde", i, 5 - i) else NONE))
                           (fromTo (~3, 8))))

  (* ---- full: "equivalent to the expression substring(s, 0, String.size s)" ---- *)
  val () = eqT ("Substring.full/basic", ("abc", 0, 3), fn () => Substring.base (Substring.full "abc"))
  val () = eqT ("Substring.full/empty-string", ("", 0, 0), fn () => Substring.base (Substring.full ""))
  val () = eqT ("Substring.full/one-character", ("x", 0, 1), fn () => Substring.base (Substring.full "x"))
  val () = eqS ("Substring.full/string", "abc", fn () => Substring.string (Substring.full "abc"))
  val () = eqI ("Substring.full/all-256-characters", 256,
                fn () => Substring.size (Substring.full (String.implode (List.tabulate (256, Char.chr)))))

  (* ---- string: "equivalent to String.substring o base" ---- *)
  val () = eqS ("Substring.string/middle", "cdef", fn () => Substring.string (mid ()))
  val () = eqS ("Substring.string/empty", "", fn () => Substring.string (nothing ()))
  val () = eqS ("Substring.string/whole", s8, fn () => Substring.string (Substring.full s8))
  val () = eqS ("Substring.string/last-character", "h", fn () => Substring.string (Substring.substring (s8, 7, 1)))
  val () = eqS ("Substring.string/String.substring-of-base", "cdef", fn () => String.substring (Substring.base (mid ())))
  val () = eqS ("Substring.string/characters-0-and-255", "\000\255",
                fn () => Substring.string (Substring.substring ("a\000\255b", 1, 2)))

  (* ---- size: "equivalent to #3 o base and String.size o string" ---- *)
  val () = eqI ("Substring.size/middle", 4, fn () => Substring.size (mid ()))
  val () = eqI ("Substring.size/empty", 0, fn () => Substring.size (nothing ()))
  val () = eqI ("Substring.size/whole", 8, fn () => Substring.size (Substring.full s8))
  val () = eqI ("Substring.size/empty-string", 0, fn () => Substring.size (Substring.full ""))
  val () = eqI ("Substring.size/third-of-base", 4, fn () => #3 (Substring.base (mid ())))
  val () = eqI ("Substring.size/size-of-string", 4, fn () => String.size (Substring.string (mid ())))

  (* ---- isEmpty: "returns true if s has size 0" ---- *)
  val () = eqB ("Substring.isEmpty/empty-string", true, fn () => Substring.isEmpty (Substring.full ""))
  val () = eqB ("Substring.isEmpty/empty-inside", true, fn () => Substring.isEmpty (nothing ()))
  val () = eqB ("Substring.isEmpty/empty-at-size", true, fn () => Substring.isEmpty (Substring.extract (s8, 8, NONE)))
  val () = eqB ("Substring.isEmpty/empty-at-start", true, fn () => Substring.isEmpty (Substring.substring (s8, 0, 0)))
  val () = eqB ("Substring.isEmpty/one-character", false, fn () => Substring.isEmpty (Substring.substring (s8, 7, 1)))
  val () = eqB ("Substring.isEmpty/middle", false, fn () => Substring.isEmpty (mid ()))

  (* ---- sub ----
     "returns the i(th) character in the substring, counting from the beginning
     of s. It is equivalent to String.sub(string s, i). The exception Subscript
     is raised unless 0 <= i < |s|." *)
  val () = T.eq T.char ("Substring.sub/first", #"c", fn () => Substring.sub (mid (), 0))
  val () = T.eq T.char ("Substring.sub/inside", #"e", fn () => Substring.sub (mid (), 2))
  val () = T.eq T.char ("Substring.sub/last", #"f", fn () => Substring.sub (mid (), 3))
  val () = T.eq T.char ("Substring.sub/whole-string", #"h", fn () => Substring.sub (Substring.full s8, 7))
  val () = eqCL ("Substring.sub/every-index", [#"c", #"d", #"e", #"f"],
                 fn () => List.map (fn i => Substring.sub (mid (), i)) [0, 1, 2, 3])
  (* the underlying string has characters there, the substring has not *)
  val () = T.raises ("Substring.sub/Subscript-at-size", T.isSubscript, fn () => Substring.sub (mid (), 4))
  val () = T.raises ("Substring.sub/Subscript-beyond-size", T.isSubscript, fn () => Substring.sub (mid (), 5))
  val () = T.raises ("Substring.sub/Subscript-negative", T.isSubscript, fn () => Substring.sub (mid (), ~1))
  val () = T.raises ("Substring.sub/Subscript-negative-before-the-string", T.isSubscript, fn () => Substring.sub (mid (), ~3))
  val () = T.raises ("Substring.sub/Subscript-empty", T.isSubscript, fn () => Substring.sub (nothing (), 0))
  val () = T.raises ("Substring.sub/Subscript-empty-string", T.isSubscript, fn () => Substring.sub (Substring.full "", 0))
  val () = T.raises ("Substring.sub/Subscript-whole-string-at-size", T.isSubscript, fn () => Substring.sub (Substring.full s8, 8))

  (* ---- getc, first ----
     "returns the first character in s and the rest of the substring, or NONE if
     s is empty" *)
  val () = eqG ("Substring.getc/middle", SOME (#"c", (s8, 3, 3)),
                fn () => Option.map (fn (c, r) => (c, Substring.base r)) (Substring.getc (mid ())))
  val () = eqG ("Substring.getc/whole", SOME (#"a", (s8, 1, 7)),
                fn () => Option.map (fn (c, r) => (c, Substring.base r)) (Substring.getc (Substring.full s8)))
  val () = eqG ("Substring.getc/one-character", SOME (#"d", (s8, 4, 0)),
                fn () => Option.map (fn (c, r) => (c, Substring.base r)) (Substring.getc (Substring.substring (s8, 3, 1))))
  val () = eqG ("Substring.getc/last-of-string", SOME (#"h", (s8, 8, 0)),
                fn () => Option.map (fn (c, r) => (c, Substring.base r)) (Substring.getc (Substring.substring (s8, 7, 1))))
  (* the substring is empty although the underlying string goes on *)
  val () = eqG ("Substring.getc/NONE-empty-inside", NONE,
                fn () => Option.map (fn (c, r) => (c, Substring.base r)) (Substring.getc (nothing ())))
  val () = eqG ("Substring.getc/NONE-empty-string", NONE,
                fn () => Option.map (fn (c, r) => (c, Substring.base r)) (Substring.getc (Substring.full "")))
  (* getc is a reader: reading until NONE yields the characters of the substring *)
  val () = eqCL ("Substring.getc/reads-the-substring", [#"c", #"d", #"e", #"f"],
                 fn () => let fun go ss = case Substring.getc ss of NONE => [] | SOME (c, ss') => c :: go ss'
                          in go (mid ()) end)
  val () = eqCO ("Substring.first/middle", SOME #"c", fn () => Substring.first (mid ()))
  val () = eqCO ("Substring.first/whole", SOME #"a", fn () => Substring.first (Substring.full s8))
  val () = eqCO ("Substring.first/one-character", SOME #"h", fn () => Substring.first (Substring.substring (s8, 7, 1)))
  val () = eqCO ("Substring.first/NONE-empty-inside", NONE, fn () => Substring.first (nothing ()))
  val () = eqCO ("Substring.first/NONE-empty-at-size", NONE, fn () => Substring.first (Substring.extract (s8, 8, NONE)))
  val () = eqCO ("Substring.first/NONE-empty-string", NONE, fn () => Substring.first (Substring.full ""))
  (*<< StringCvt *)
  (* StringCvt: "Character readers are provided for the common sources of
     characters, either explicitly, such as the SUBSTRING.getc ..." *)
  val () = T.eq (T.pair (T.string, showT)) ("Substring.getc/reader-for-StringCvt.splitl", ("12", ("x12ab", 3, 2)),
             fn () => let val (pref, rest) = StringCvt.splitl Char.isDigit Substring.getc (Substring.extract ("x12ab", 1, NONE))
                      in (pref, Substring.base rest) end)
  val () = eqT ("Substring.getc/reader-for-StringCvt.skipWS", ("  ab ", 2, 2),
                fn () => Substring.base (StringCvt.skipWS Substring.getc (Substring.substring ("  ab ", 0, 4))))
  (*>> StringCvt *)
  (*<< Int.scan *)
  (* StringCvt: "to receive a scanned value and the unscanned portion of a
     string ... combine scanning functions with Substring.getc" *)
  val () = T.eq (T.option (T.pair (T.int, showT))) ("Substring.getc/reader-for-Int.scan", SOME (42, ("x42y7", 3, 1)),
             fn () => Option.map (fn (v, r) => (v, Substring.base r))
                        (Int.scan StringCvt.DEC Substring.getc (Substring.substring ("x42y7", 1, 3))))
  (* the digit after the end of the substring is not read *)
  val () = T.eq (T.option (T.pair (T.int, showT))) ("Substring.getc/reader-stops-at-the-end", SOME (12, ("1234", 2, 0)),
             fn () => Option.map (fn (v, r) => (v, Substring.base r))
                        (Int.scan StringCvt.DEC Substring.getc (Substring.substring ("1234", 0, 2))))
  (*>> Int.scan *)

  (* ---- triml, trimr ----
     "for substring ss = substring(s, i, j) and k <= j, we have:
       triml k ss = substring(s, i+k, j-k)
       trimr k ss = substring(s, i, j-k)" *)
  val () = eqT ("Substring.triml/one", (s8, 3, 3), fn () => Substring.base (Substring.triml 1 (mid ())))
  val () = eqT ("Substring.trimr/one", (s8, 2, 3), fn () => Substring.base (Substring.trimr 1 (mid ())))
  val () = eqT ("Substring.triml/zero", (s8, 2, 4), fn () => Substring.base (Substring.triml 0 (mid ())))
  val () = eqT ("Substring.trimr/zero", (s8, 2, 4), fn () => Substring.base (Substring.trimr 0 (mid ())))
  val () = eqT ("Substring.triml/three", (s8, 5, 1), fn () => Substring.base (Substring.triml 3 (mid ())))
  val () = eqT ("Substring.trimr/three", (s8, 2, 1), fn () => Substring.base (Substring.trimr 3 (mid ())))
  val () = eqT ("Substring.triml/size", (s8, 6, 0), fn () => Substring.base (Substring.triml 4 (mid ())))
  val () = eqT ("Substring.trimr/size", (s8, 2, 0), fn () => Substring.base (Substring.trimr 4 (mid ())))
  val () = eqT ("Substring.triml/zero-of-empty", (s8, 3, 0), fn () => Substring.base (Substring.triml 0 (nothing ())))
  val () = eqT ("Substring.trimr/zero-of-empty", (s8, 3, 0), fn () => Substring.base (Substring.trimr 0 (nothing ())))
  val () = eqS ("Substring.triml/string", "ef", fn () => Substring.string (Substring.triml 2 (mid ())))
  val () = eqS ("Substring.trimr/string", "cd", fn () => Substring.string (Substring.trimr 2 (mid ())))
  (* "If k is greater than the size of the substring, an empty substring is
     returned.": although the underlying string has the characters *)
  fun emptyWithin (ss, (s, i, n)) =
    let val (s', i', n') = Substring.base ss
    in Substring.isEmpty ss andalso Substring.size ss = 0 andalso Substring.string ss = ""
       andalso s' = s andalso n' = 0 andalso i <= i' andalso i' <= i + n end
  val () = T.check ("Substring.triml/beyond-size", fn () => emptyWithin (Substring.triml 5 (mid ()), (s8, 2, 4)))
  val () = T.check ("Substring.trimr/beyond-size", fn () => emptyWithin (Substring.trimr 5 (mid ()), (s8, 2, 4)))
  val () = T.check ("Substring.triml/far-beyond-size", fn () => emptyWithin (Substring.triml 100 (mid ()), (s8, 2, 4)))
  val () = T.check ("Substring.trimr/far-beyond-size", fn () => emptyWithin (Substring.trimr 100 (mid ()), (s8, 2, 4)))
  val () = T.check ("Substring.triml/beyond-size-of-empty", fn () => emptyWithin (Substring.triml 1 (nothing ()), (s8, 3, 0)))
  val () = T.check ("Substring.trimr/beyond-size-of-empty", fn () => emptyWithin (Substring.trimr 1 (nothing ()), (s8, 3, 0)))
  (* "The exception Subscript is raised if k < 0. This exception is raised when
     triml k or trimr k is evaluated." *)
  val () = T.raises ("Substring.triml/Subscript-negative", T.isSubscript, fn () => Substring.triml ~1 (mid ()))
  val () = T.raises ("Substring.trimr/Subscript-negative", T.isSubscript, fn () => Substring.trimr ~1 (mid ()))
  val () = T.raises ("Substring.triml/Subscript-negative-empty", T.isSubscript, fn () => Substring.triml ~1 (nothing ()))
  val () = T.raises ("Substring.trimr/Subscript-negative-empty", T.isSubscript, fn () => Substring.trimr ~1 (nothing ()))
  val () = T.raises ("Substring.triml/Subscript-when-k-is-given", T.isSubscript, fn () => Substring.triml ~1)
  val () = T.raises ("Substring.trimr/Subscript-when-k-is-given", T.isSubscript, fn () => Substring.trimr ~1)
  val () = T.eq (T.list showT) ("Substring.triml/partial-application", [(s8, 2, 6), ("xyz", 2, 1)],
             fn () => bases (List.map (Substring.triml 2) [Substring.full s8, Substring.full "xyz"]))
  val () = T.eq (T.list showT) ("Substring.trimr/partial-application", [(s8, 0, 6), ("xyz", 0, 1)],
             fn () => bases (List.map (Substring.trimr 2) [Substring.full s8, Substring.full "xyz"]))

  (* ---- slice ----
     "These return a substring of s starting at the i(th) character. In the
     former case, the size of the resulting substring is m. Otherwise, the size
     is |s| - i. To be valid, the arguments in the first case must satisfy 0 <=
     i, 0 <= m and i + m <= |s|. In the second case, the arguments must satisfy
     0 <= i <= |s|. If the arguments are not valid, the exception Subscript is
     raised." *)
  val () = eqT ("Substring.slice/SOME-inside", (s8, 3, 2), fn () => Substring.base (Substring.slice (mid (), 1, SOME 2)))
  val () = eqT ("Substring.slice/SOME-whole", (s8, 2, 4), fn () => Substring.base (Substring.slice (mid (), 0, SOME 4)))
  val () = eqT ("Substring.slice/SOME-to-the-end", (s8, 4, 2), fn () => Substring.base (Substring.slice (mid (), 2, SOME 2)))
  val () = eqT ("Substring.slice/SOME-zero-at-start", (s8, 2, 0), fn () => Substring.base (Substring.slice (mid (), 0, SOME 0)))
  val () = eqT ("Substring.slice/SOME-zero-at-size", (s8, 6, 0), fn () => Substring.base (Substring.slice (mid (), 4, SOME 0)))
  val () = eqT ("Substring.slice/SOME-of-empty", (s8, 3, 0), fn () => Substring.base (Substring.slice (nothing (), 0, SOME 0)))
  val () = eqT ("Substring.slice/NONE-whole", (s8, 2, 4), fn () => Substring.base (Substring.slice (mid (), 0, NONE)))
  val () = eqT ("Substring.slice/NONE-inside", (s8, 3, 3), fn () => Substring.base (Substring.slice (mid (), 1, NONE)))
  val () = eqT ("Substring.slice/NONE-at-size", (s8, 6, 0), fn () => Substring.base (Substring.slice (mid (), 4, NONE)))
  val () = eqT ("Substring.slice/NONE-of-empty", (s8, 3, 0), fn () => Substring.base (Substring.slice (nothing (), 0, NONE)))
  val () = eqS ("Substring.slice/SOME-string", "de", fn () => Substring.string (Substring.slice (mid (), 1, SOME 2)))
  val () = eqS ("Substring.slice/NONE-string", "def", fn () => Substring.string (Substring.slice (mid (), 1, NONE)))
  val () = eqT ("Substring.slice/of-a-slice", (s8, 4, 1),
                fn () => Substring.base (Substring.slice (Substring.slice (mid (), 1, NONE), 1, SOME 1)))
  (* the underlying string has the characters, the substring has not *)
  val () = T.raises ("Substring.slice/SOME-Subscript-end-beyond-size", T.isSubscript, fn () => Substring.slice (mid (), 2, SOME 3))
  val () = T.raises ("Substring.slice/SOME-Subscript-too-long", T.isSubscript, fn () => Substring.slice (mid (), 0, SOME 5))
  val () = T.raises ("Substring.slice/SOME-Subscript-start-beyond-size", T.isSubscript, fn () => Substring.slice (mid (), 5, SOME 0))
  val () = T.raises ("Substring.slice/SOME-Subscript-negative-start", T.isSubscript, fn () => Substring.slice (mid (), ~1, SOME 1))
  val () = T.raises ("Substring.slice/SOME-Subscript-negative-size", T.isSubscript, fn () => Substring.slice (mid (), 1, SOME ~1))
  val () = T.raises ("Substring.slice/SOME-Subscript-negative-size-end-inside", T.isSubscript, fn () => Substring.slice (mid (), 3, SOME ~2))
  val () = T.raises ("Substring.slice/SOME-Subscript-of-empty", T.isSubscript, fn () => Substring.slice (nothing (), 0, SOME 1))
  val () = T.raises ("Substring.slice/NONE-Subscript-beyond-size", T.isSubscript, fn () => Substring.slice (mid (), 5, NONE))
  val () = T.raises ("Substring.slice/NONE-Subscript-negative", T.isSubscript, fn () => Substring.slice (mid (), ~1, NONE))
  val () = T.raises ("Substring.slice/NONE-Subscript-of-empty", T.isSubscript, fn () => Substring.slice (nothing (), 1, NONE))
  (* every (i, m) with ~3 <= i, m <= 6: the slice, or Subscript *)
  val () = eqI ("Substring.slice/SOME-every-argument", 0,
                fn () => List.length (List.filter (fn (i, m) =>
                             (SOME (Substring.base (Substring.slice (mid (), i, SOME m))) handle Subscript => NONE)
                             <> (if 0 <= i andalso 0 <= m andalso i + m <= 4 then SOME (s8, 2 + i, m) else NONE))
                           (List.concat (List.map (fn i => List.map (fn m => (i, m)) (fromTo (~3, 6))) (fromTo (~3, 6))))))
  val () = eqI ("Substring.slice/NONE-every-argument", 0,
                fn () => List.length (List.filter (fn i =>
                             (SOME (Substring.base (Substring.slice (mid (), i, NONE))) handle Subscript => NONE)
                             <> (if 0 <= i andalso i <= 4 then SOME (s8, 2 + i, 4 - i) else NONE))
                           (fromTo (~3, 6))))

  (*<< overflow *)
  (* "Implementations of these functions must perform bounds checking in such a
     way that the Overflow exception is not raised." In the checks labelled
     sum-* both numbers are valid by themselves and their sum does not exist. *)
  val () = T.raises ("Substring.substring/Subscript-not-Overflow-sum-size", T.isSubscript, fn () => Substring.substring ("abcde", 1, big))
  val () = T.raises ("Substring.substring/Subscript-not-Overflow-sum-start", T.isSubscript, fn () => Substring.substring ("abcde", big, 1))
  val () = T.raises ("Substring.substring/Subscript-not-Overflow-sum-both", T.isSubscript, fn () => Substring.substring ("abcde", big, big))
  val () = T.raises ("Substring.substring/Subscript-not-Overflow-start-zero-size", T.isSubscript, fn () => Substring.substring ("abcde", big, 0))
  val () = T.raises ("Substring.substring/Subscript-not-Overflow-smallest-start", T.isSubscript, fn () => Substring.substring ("abcde", small, 1))
  val () = T.raises ("Substring.substring/Subscript-not-Overflow-smallest-size", T.isSubscript, fn () => Substring.substring ("abcde", 1, small))
  val () = T.raises ("Substring.substring/Subscript-not-Overflow-smallest-both", T.isSubscript, fn () => Substring.substring ("abcde", small, small))
  val () = T.raises ("Substring.substring/Subscript-not-Overflow-smallest-and-largest", T.isSubscript, fn () => Substring.substring ("abcde", small, big))
  val () = T.raises ("Substring.extract/SOME-Subscript-not-Overflow-sum-size", T.isSubscript, fn () => Substring.extract ("abcde", 1, SOME big))
  val () = T.raises ("Substring.extract/SOME-Subscript-not-Overflow-sum-start", T.isSubscript, fn () => Substring.extract ("abcde", big, SOME 1))
  val () = T.raises ("Substring.extract/SOME-Subscript-not-Overflow-sum-both", T.isSubscript, fn () => Substring.extract ("abcde", big, SOME big))
  val () = T.raises ("Substring.extract/SOME-Subscript-not-Overflow-smallest-size", T.isSubscript, fn () => Substring.extract ("abcde", 1, SOME small))
  val () = T.raises ("Substring.extract/NONE-Subscript-not-Overflow", T.isSubscript, fn () => Substring.extract ("abcde", big, NONE))
  val () = T.raises ("Substring.extract/NONE-Subscript-not-Overflow-smallest", T.isSubscript, fn () => Substring.extract ("abcde", small, NONE))
  (* the same care is needed for a substring that starts inside its string *)
  val () = T.raises ("Substring.slice/SOME-Subscript-not-Overflow-sum-size", T.isSubscript, fn () => Substring.slice (mid (), 1, SOME big))
  val () = T.raises ("Substring.slice/SOME-Subscript-not-Overflow-sum-start", T.isSubscript, fn () => Substring.slice (mid (), big, SOME 1))
  val () = T.raises ("Substring.slice/SOME-Subscript-not-Overflow-sum-both", T.isSubscript, fn () => Substring.slice (mid (), big, SOME big))
  val () = T.raises ("Substring.slice/SOME-Subscript-not-Overflow-smallest-size", T.isSubscript, fn () => Substring.slice (mid (), 1, SOME small))
  val () = T.raises ("Substring.slice/NONE-Subscript-not-Overflow", T.isSubscript, fn () => Substring.slice (mid (), big, NONE))
  val () = T.raises ("Substring.slice/NONE-Subscript-not-Overflow-smallest", T.isSubscript, fn () => Substring.slice (mid (), small, NONE))
  val () = T.raises ("Substring.sub/Subscript-not-Overflow", T.isSubscript, fn () => Substring.sub (mid (), big))
  val () = T.raises ("Substring.sub/Subscript-not-Overflow-smallest", T.isSubscript, fn () => Substring.sub (mid (), small))
  val () = T.raises ("Substring.splitAt/Subscript-not-Overflow", T.isSubscript, fn () => Substring.splitAt (mid (), big))
  val () = T.raises ("Substring.splitAt/Subscript-not-Overflow-smallest", T.isSubscript, fn () => Substring.splitAt (mid (), small))
  val () = T.check ("Substring.triml/largest-k", fn () => emptyWithin (Substring.triml big (mid ()), (s8, 2, 4)))
  val () = T.check ("Substring.trimr/largest-k", fn () => emptyWithin (Substring.trimr big (mid ()), (s8, 2, 4)))
  val () = T.raises ("Substring.triml/Subscript-smallest-k", T.isSubscript, fn () => Substring.triml small (mid ()))
  val () = T.raises ("Substring.trimr/Subscript-smallest-k", T.isSubscript, fn () => Substring.trimr small (mid ()))
  (*>> overflow *)

  (* ---- concat: "equivalent to String.concat o (List.map string)" ---- *)
  val () = eqS ("Substring.concat/nil", "", fn () => Substring.concat [])
  val () = eqS ("Substring.concat/one", "cdef", fn () => Substring.concat [mid ()])
  val () = eqS ("Substring.concat/several-strings", "abghy",
                fn () => Substring.concat [Substring.substring (s8, 0, 2), Substring.substring (s8, 6, 2), Substring.substring ("xyz", 1, 1)])
  val () = eqS ("Substring.concat/with-empty-substrings", "cdefcdef",
                fn () => Substring.concat [nothing (), mid (), nothing (), nothing (), mid (), Substring.full ""])
  val () = eqS ("Substring.concat/only-empty-substrings", "", fn () => Substring.concat [nothing (), Substring.full ""])
  val () = eqS ("Substring.concat/overlapping", "abcbcdcd",
                fn () => Substring.concat [Substring.substring (s8, 0, 3), Substring.substring (s8, 1, 3), Substring.substring (s8, 2, 2)])
  val () = eqI ("Substring.concat/many", 30000,
                fn () => String.size (Substring.concat (List.tabulate (10000, fn _ => Substring.substring (s8, 5, 3)))))

  (* ---- concatWith: "the concatenation of the substrings in the list l using
     the string s as a separator" ---- *)
  val () = eqS ("Substring.concatWith/nil", "", fn () => Substring.concatWith ", " [])
  val () = eqS ("Substring.concatWith/one", "cdef", fn () => Substring.concatWith ", " [mid ()])
  val () = eqS ("Substring.concatWith/two", "cdef, ab", fn () => Substring.concatWith ", " [mid (), Substring.substring (s8, 0, 2)])
  val () = eqS ("Substring.concatWith/several-strings", "ab-gh-y",
                fn () => Substring.concatWith "-" [Substring.substring (s8, 0, 2), Substring.substring (s8, 6, 2), Substring.substring ("xyz", 1, 1)])
  val () = eqS ("Substring.concatWith/empty-separator", "abghy",
                fn () => Substring.concatWith "" [Substring.substring (s8, 0, 2), Substring.substring (s8, 6, 2), Substring.substring ("xyz", 1, 1)])
  val () = eqS ("Substring.concatWith/empty-substrings-are-separated", "--", fn () => Substring.concatWith "-" [nothing (), nothing (), nothing ()])
  val () = eqS ("Substring.concatWith/empty-substring-first-and-last", "-cdef-", fn () => Substring.concatWith "-" [nothing (), mid (), nothing ()])
  val () = eqS ("Substring.concatWith/one-empty", "", fn () => Substring.concatWith "-" [nothing ()])

  (* "This raises Size if the sum of all the sizes is greater than the
     corresponding maxSize for the string type." (see the header) *)
  val () =
    if String.maxSize <= 67108864 then
      let
        val piece = 65536
        val count = String.maxSize div piece + 1
        fun pieces () =
          let val ss = Substring.full (String.implode (List.tabulate (piece, fn _ => #"x")))
          in List.tabulate (count, fn _ => ss) end
      in
        T.raises ("Substring.concat/Size", T.isSize, fn () => Substring.concat (pieces ()));
        T.raises ("Substring.concatWith/Size", T.isSize, fn () => Substring.concatWith "" (pieces ()));
        T.raises ("Substring.concatWith/Size-by-the-separators", T.isSize,
                  fn () => Substring.concatWith (String.implode (List.tabulate (piece, fn _ => #"-")))
                             (List.tabulate (count + 2, fn _ => Substring.substring ("", 0, 0))))
      end
    else ()

  (* ---- explode: "equivalent to String.explode (string s)" ---- *)
  val () = eqCL ("Substring.explode/middle", [#"c", #"d", #"e", #"f"], fn () => Substring.explode (mid ()))
  val () = eqCL ("Substring.explode/empty", [], fn () => Substring.explode (nothing ()))
  val () = eqCL ("Substring.explode/empty-string", [], fn () => Substring.explode (Substring.full ""))
  val () = eqCL ("Substring.explode/whole", String.explode s8, fn () => Substring.explode (Substring.full s8))
  val () = eqCL ("Substring.explode/one-character", [#"h"], fn () => Substring.explode (Substring.substring (s8, 7, 1)))

  (* ---- isPrefix, isSubstring, isSuffix ----
     "isPrefix s ss is the same as String.isPrefix s (string ss)": what the
     underlying string has around the substring does not count. *)
  val () = eqB ("Substring.isPrefix/true", true, fn () => Substring.isPrefix "cd" (mid ()))
  val () = eqB ("Substring.isPrefix/one-character", true, fn () => Substring.isPrefix "c" (mid ()))
  val () = eqB ("Substring.isPrefix/whole", true, fn () => Substring.isPrefix "cdef" (mid ()))
  val () = eqB ("Substring.isPrefix/empty-string", true, fn () => Substring.isPrefix "" (mid ()))
  val () = eqB ("Substring.isPrefix/empty-of-empty", true, fn () => Substring.isPrefix "" (nothing ()))
  val () = eqB ("Substring.isPrefix/nonempty-of-empty", false, fn () => Substring.isPrefix "d" (nothing ()))
  val () = eqB ("Substring.isPrefix/goes-on-in-the-underlying-string", false, fn () => Substring.isPrefix "cdefg" (mid ()))
  val () = eqB ("Substring.isPrefix/prefix-of-the-underlying-string", false, fn () => Substring.isPrefix "ab" (mid ()))
  val () = eqB ("Substring.isPrefix/starts-before", false, fn () => Substring.isPrefix "bc" (mid ()))
  val () = eqB ("Substring.isPrefix/inside-only", false, fn () => Substring.isPrefix "de" (mid ()))
  val () = eqB ("Substring.isPrefix/differs-at-the-end", false, fn () => Substring.isPrefix "cdex" (mid ()))
  val () = eqB ("Substring.isSuffix/true", true, fn () => Substring.isSuffix "ef" (mid ()))
  val () = eqB ("Substring.isSuffix/one-character", true, fn () => Substring.isSuffix "f" (mid ()))
  val () = eqB ("Substring.isSuffix/whole", true, fn () => Substring.isSuffix "cdef" (mid ()))
  val () = eqB ("Substring.isSuffix/empty-string", true, fn () => Substring.isSuffix "" (mid ()))
  val () = eqB ("Substring.isSuffix/empty-of-empty", true, fn () => Substring.isSuffix "" (nothing ()))
  val () = eqB ("Substring.isSuffix/nonempty-of-empty", false, fn () => Substring.isSuffix "c" (nothing ()))
  val () = eqB ("Substring.isSuffix/starts-in-the-underlying-string", false, fn () => Substring.isSuffix "bcdef" (mid ()))
  val () = eqB ("Substring.isSuffix/suffix-of-the-underlying-string", false, fn () => Substring.isSuffix "gh" (mid ()))
  val () = eqB ("Substring.isSuffix/ends-after", false, fn () => Substring.isSuffix "fg" (mid ()))
  val () = eqB ("Substring.isSuffix/inside-only", false, fn () => Substring.isSuffix "de" (mid ()))
  val () = eqB ("Substring.isSuffix/differs-at-the-start", false, fn () => Substring.isSuffix "xdef" (mid ()))
  val () = eqB ("Substring.isSubstring/inside", true, fn () => Substring.isSubstring "de" (mid ()))
  val () = eqB ("Substring.isSubstring/prefix", true, fn () => Substring.isSubstring "cd" (mid ()))
  val () = eqB ("Substring.isSubstring/suffix", true, fn () => Substring.isSubstring "ef" (mid ()))
  val () = eqB ("Substring.isSubstring/whole", true, fn () => Substring.isSubstring "cdef" (mid ()))
  val () = eqB ("Substring.isSubstring/empty-string", true, fn () => Substring.isSubstring "" (mid ()))
  val () = eqB ("Substring.isSubstring/empty-of-empty", true, fn () => Substring.isSubstring "" (nothing ()))
  val () = eqB ("Substring.isSubstring/nonempty-of-empty", false, fn () => Substring.isSubstring "d" (nothing ()))
  val () = eqB ("Substring.isSubstring/ends-after", false, fn () => Substring.isSubstring "fg" (mid ()))
  val () = eqB ("Substring.isSubstring/starts-before", false, fn () => Substring.isSubstring "bc" (mid ()))
  val () = eqB ("Substring.isSubstring/contains-the-substring", false, fn () => Substring.isSubstring "bcdefg" (mid ()))
  val () = eqB ("Substring.isSubstring/elsewhere-in-the-underlying-string", false, fn () => Substring.isSubstring "gh" (mid ()))
  val () = eqB ("Substring.isSubstring/not-contiguous", false, fn () => Substring.isSubstring "ce" (mid ()))
  val () = eqB ("Substring.isSubstring/after-a-partial-match", true,
                fn () => Substring.isSubstring "aab" (Substring.substring ("xaaabx", 1, 4)))

  (* ---- compare: "equivalent to String.compare (string s, string t)" ---- *)
  val () = eqOrd ("Substring.compare/less", LESS, fn () => Substring.compare (Substring.full "abc", Substring.full "abd"))
  val () = eqOrd ("Substring.compare/greater", GREATER, fn () => Substring.compare (Substring.full "abd", Substring.full "abc"))
  val () = eqOrd ("Substring.compare/equal", EQUAL, fn () => Substring.compare (Substring.full "abc", Substring.full "abc"))
  val () = eqOrd ("Substring.compare/prefix-is-less", LESS, fn () => Substring.compare (Substring.full "ab", Substring.full "abc"))
  val () = eqOrd ("Substring.compare/longer-is-greater", GREATER, fn () => Substring.compare (Substring.full "abc", Substring.full "ab"))
  val () = eqOrd ("Substring.compare/first-difference-decides", GREATER, fn () => Substring.compare (Substring.full "b", Substring.full "abc"))
  val () = eqOrd ("Substring.compare/empty-empty", EQUAL, fn () => Substring.compare (Substring.full "", nothing ()))
  val () = eqOrd ("Substring.compare/empty-less", LESS, fn () => Substring.compare (nothing (), Substring.full "a"))
  val () = eqOrd ("Substring.compare/upper-before-lower", LESS, fn () => Substring.compare (Substring.full "Z", Substring.full "a"))
  val () = eqOrd ("Substring.compare/character-255-last", GREATER, fn () => Substring.compare (Substring.full "\255", Substring.full "z"))
  (* the characters count, not where they are *)
  val () = eqOrd ("Substring.compare/equal-in-different-strings", EQUAL,
                  fn () => Substring.compare (Substring.substring ("xabcx", 1, 3), Substring.substring ("abcyy", 0, 3)))
  val () = eqOrd ("Substring.compare/equal-at-different-places", EQUAL,
                  fn () => Substring.compare (Substring.substring ("abab", 0, 2), Substring.substring ("abab", 2, 2)))
  val () = eqOrd ("Substring.compare/same-start-different-size", LESS,
                  fn () => Substring.compare (Substring.substring (s8, 2, 2), Substring.substring (s8, 2, 3)))
  val () = eqOrd ("Substring.compare/what-follows-does-not-count", EQUAL,
                  fn () => Substring.compare (Substring.substring ("abz", 0, 2), Substring.substring ("aba", 0, 2)))

  (* ---- collate: "equivalent to String.collate f (string s, string t)" ---- *)
  fun reversed (a, b) = Char.compare (b, a)
  fun caseless (a, b) = Char.compare (Char.toLower a, Char.toLower b)
  val () = eqOrd ("Substring.collate/Char.compare", LESS, fn () => Substring.collate Char.compare (Substring.full "abc", Substring.full "abd"))
  val () = eqOrd ("Substring.collate/reversed-order", GREATER, fn () => Substring.collate reversed (Substring.full "abc", Substring.full "abd"))
  val () = eqOrd ("Substring.collate/reversed-order-prefix", LESS, fn () => Substring.collate reversed (Substring.full "ab", Substring.full "abc"))
  val () = eqOrd ("Substring.collate/reversed-order-longer", GREATER, fn () => Substring.collate reversed (Substring.full "abc", Substring.full "ab"))
  val () = eqOrd ("Substring.collate/caseless-equal", EQUAL, fn () => Substring.collate caseless (Substring.full "aBc", Substring.full "AbC"))
  val () = eqOrd ("Substring.collate/caseless-less", LESS, fn () => Substring.collate caseless (Substring.full "ABC", Substring.full "abd"))
  val () = eqOrd ("Substring.collate/empty-empty", EQUAL, fn () => Substring.collate reversed (nothing (), Substring.full ""))
  val () = eqOrd ("Substring.collate/always-equal-size-decides", LESS,
                  fn () => Substring.collate (fn _ => EQUAL) (Substring.full "xy", Substring.full "abc"))
  val () = eqOrd ("Substring.collate/inside-strings", GREATER,
                  fn () => Substring.collate reversed (Substring.substring ("zabz", 1, 2), Substring.substring ("aacz", 1, 2)))
  (* lexicographic: pairs from the left, up to the first that differs *)
  val () = T.eq (T.list (T.pair (T.char, T.char))) ("Substring.collate/order", [(#"a", #"a"), (#"b", #"b"), (#"c", #"d")],
             fn () => let val log = ref []
                      in ignore (Substring.collate (fn (a, b) => (log := (a, b) :: !log; Char.compare (a, b)))
                                   (Substring.substring ("xabcpx", 1, 4), Substring.substring ("abdqyy", 0, 4)));
                         List.rev (!log) end)

  (* ---- splitl, splitr ----
     "These functions scan s from left to right (respectively, right to left)
     looking for the first character that does not satisfy the predicate f.
     They return the pair (ls, rs) giving the split of the substring into the
     span up to that character and the rest." *)
  val page = "aaaXbbbbXccc"
  fun aOrC c = c = #"a" orelse c = #"c"
  val () = eqTT ("Substring.splitl/page-example", ((page, 0, 3), (page, 3, 9)), fn () => base2 (Substring.splitl aOrC (Substring.full page)))
  val () = eqTT ("Substring.splitr/page-example", ((page, 0, 9), (page, 9, 3)), fn () => base2 (Substring.splitr aOrC (Substring.full page)))
  val () = T.eq (T.pair (T.string, T.string)) ("Substring.splitl/page-example-strings", ("aaa", "XbbbbXccc"),
             fn () => let val (l, r) = Substring.splitl aOrC (Substring.full page) in (Substring.string l, Substring.string r) end)
  val () = T.eq (T.pair (T.string, T.string)) ("Substring.splitr/page-example-strings", ("aaaXbbbbX", "ccc"),
             fn () => let val (l, r) = Substring.splitr aOrC (Substring.full page) in (Substring.string l, Substring.string r) end)
  val () = eqTT ("Substring.splitl/all-satisfy", ((s8, 2, 4), (s8, 6, 0)), fn () => base2 (Substring.splitl (fn _ => true) (mid ())))
  val () = eqTT ("Substring.splitr/all-satisfy", ((s8, 2, 0), (s8, 2, 4)), fn () => base2 (Substring.splitr (fn _ => true) (mid ())))
  val () = eqTT ("Substring.splitl/none-satisfies", ((s8, 2, 0), (s8, 2, 4)), fn () => base2 (Substring.splitl (fn _ => false) (mid ())))
  val () = eqTT ("Substring.splitr/none-satisfies", ((s8, 2, 4), (s8, 6, 0)), fn () => base2 (Substring.splitr (fn _ => false) (mid ())))
  val () = eqTT ("Substring.splitl/empty", ((s8, 3, 0), (s8, 3, 0)), fn () => base2 (Substring.splitl (fn _ => true) (nothing ())))
  val () = eqTT ("Substring.splitr/empty", ((s8, 3, 0), (s8, 3, 0)), fn () => base2 (Substring.splitr (fn _ => true) (nothing ())))
  val () = eqTT ("Substring.splitl/first-fails", ((s8, 2, 0), (s8, 2, 4)), fn () => base2 (Substring.splitl (fn c => c <> #"c") (mid ())))
  val () = eqTT ("Substring.splitr/last-fails", ((s8, 2, 4), (s8, 6, 0)), fn () => base2 (Substring.splitr (fn c => c <> #"f") (mid ())))
  val () = eqTT ("Substring.splitl/last-fails", ((s8, 2, 3), (s8, 5, 1)), fn () => base2 (Substring.splitl (fn c => c <> #"f") (mid ())))
  val () = eqTT ("Substring.splitr/first-fails", ((s8, 2, 1), (s8, 3, 3)), fn () => base2 (Substring.splitr (fn c => c <> #"c") (mid ())))
  (* the scan ends where the substring ends, whatever the underlying string has there *)
  val inA = "aaXaaXaa"
  val () = eqTT ("Substring.splitl/stops-at-the-end-of-the-substring", ((inA, 3, 2), (inA, 5, 0)),
                 fn () => base2 (Substring.splitl isA (Substring.substring (inA, 3, 2))))
  val () = eqTT ("Substring.splitr/stops-at-the-start-of-the-substring", ((inA, 3, 0), (inA, 3, 2)),
                 fn () => base2 (Substring.splitr isA (Substring.substring (inA, 3, 2))))
  val () = eqTT ("Substring.splitl/first-failing-of-several", ((inA, 0, 2), (inA, 2, 6)), fn () => base2 (Substring.splitl isA (Substring.full inA)))
  val () = eqTT ("Substring.splitr/first-failing-of-several", ((inA, 0, 6), (inA, 6, 2)), fn () => base2 (Substring.splitr isA (Substring.full inA)))
  val () = eqCL ("Substring.splitl/order", [#"a", #"b", #"X"],
                 fn () => let val (f, seen) = trace notX in ignore (Substring.splitl f (Substring.substring ("XabXcdX", 1, 5))); seen () end)
  val () = eqCL ("Substring.splitr/order", [#"d", #"c", #"X"],
                 fn () => let val (f, seen) = trace notX in ignore (Substring.splitr f (Substring.substring ("XabXcdX", 1, 5))); seen () end)
  val () = eqCL ("Substring.splitl/order-all-satisfy", [#"c", #"d", #"e", #"f"],
                 fn () => let val (f, seen) = trace notX in ignore (Substring.splitl f (mid ())); seen () end)
  val () = eqCL ("Substring.splitr/order-all-satisfy", [#"f", #"e", #"d", #"c"],
                 fn () => let val (f, seen) = trace notX in ignore (Substring.splitr f (mid ())); seen () end)

  (* ---- splitAt ----
     "returns the pair of substring (ss, ss'), where ss contains the first i
     characters of s and ss' contains the rest, assuming 0 <= i <= size s.
     Otherwise, it raises Subscript." *)
  val () = eqTT ("Substring.splitAt/inside", ((s8, 2, 1), (s8, 3, 3)), fn () => base2 (Substring.splitAt (mid (), 1)))
  val () = eqTT ("Substring.splitAt/zero", ((s8, 2, 0), (s8, 2, 4)), fn () => base2 (Substring.splitAt (mid (), 0)))
  val () = eqTT ("Substring.splitAt/size", ((s8, 2, 4), (s8, 6, 0)), fn () => base2 (Substring.splitAt (mid (), 4)))
  val () = eqTT ("Substring.splitAt/empty", ((s8, 3, 0), (s8, 3, 0)), fn () => base2 (Substring.splitAt (nothing (), 0)))
  val () = eqTT ("Substring.splitAt/whole-string", ((s8, 0, 5), (s8, 5, 3)), fn () => base2 (Substring.splitAt (Substring.full s8, 5)))
  val () = T.raises ("Substring.splitAt/Subscript-beyond-size", T.isSubscript, fn () => Substring.splitAt (mid (), 5))
  val () = T.raises ("Substring.splitAt/Subscript-negative", T.isSubscript, fn () => Substring.splitAt (mid (), ~1))
  val () = T.raises ("Substring.splitAt/Subscript-empty", T.isSubscript, fn () => Substring.splitAt (nothing (), 1))
  val () = T.raises ("Substring.splitAt/Subscript-empty-negative", T.isSubscript, fn () => Substring.splitAt (nothing (), ~1))

  (* ---- dropl, dropr, takel, taker ----
     "takel p s = #1(splitl p s)", "dropl p s = #2(splitl p s)",
     "taker p s = #2(splitr p s)", "dropr p s = #1(splitr p s)" *)
  val () = eqT ("Substring.takel/page-example", (page, 0, 3), fn () => Substring.base (Substring.takel aOrC (Substring.full page)))
  val () = eqT ("Substring.dropl/page-example", (page, 3, 9), fn () => Substring.base (Substring.dropl aOrC (Substring.full page)))
  val () = eqT ("Substring.taker/page-example", (page, 9, 3), fn () => Substring.base (Substring.taker aOrC (Substring.full page)))
  val () = eqT ("Substring.dropr/page-example", (page, 0, 9), fn () => Substring.base (Substring.dropr aOrC (Substring.full page)))
  val () = eqT ("Substring.takel/all-satisfy", (s8, 2, 4), fn () => Substring.base (Substring.takel (fn _ => true) (mid ())))
  val () = eqT ("Substring.dropl/all-satisfy", (s8, 6, 0), fn () => Substring.base (Substring.dropl (fn _ => true) (mid ())))
  val () = eqT ("Substring.taker/all-satisfy", (s8, 2, 4), fn () => Substring.base (Substring.taker (fn _ => true) (mid ())))
  val () = eqT ("Substring.dropr/all-satisfy", (s8, 2, 0), fn () => Substring.base (Substring.dropr (fn _ => true) (mid ())))
  val () = eqT ("Substring.takel/none-satisfies", (s8, 2, 0), fn () => Substring.base (Substring.takel (fn _ => false) (mid ())))
  val () = eqT ("Substring.dropl/none-satisfies", (s8, 2, 4), fn () => Substring.base (Substring.dropl (fn _ => false) (mid ())))
  val () = eqT ("Substring.taker/none-satisfies", (s8, 6, 0), fn () => Substring.base (Substring.taker (fn _ => false) (mid ())))
  val () = eqT ("Substring.dropr/none-satisfies", (s8, 2, 4), fn () => Substring.base (Substring.dropr (fn _ => false) (mid ())))
  val () = eqT ("Substring.takel/empty", (s8, 3, 0), fn () => Substring.base (Substring.takel (fn _ => true) (nothing ())))
  val () = eqT ("Substring.dropl/empty", (s8, 3, 0), fn () => Substring.base (Substring.dropl (fn _ => true) (nothing ())))
  val () = eqT ("Substring.taker/empty", (s8, 3, 0), fn () => Substring.base (Substring.taker (fn _ => true) (nothing ())))
  val () = eqT ("Substring.dropr/empty", (s8, 3, 0), fn () => Substring.base (Substring.dropr (fn _ => true) (nothing ())))
  val () = eqT ("Substring.takel/within-the-substring", (inA, 3, 2), fn () => Substring.base (Substring.takel isA (Substring.substring (inA, 3, 2))))
  val () = eqT ("Substring.dropl/within-the-substring", (inA, 5, 0), fn () => Substring.base (Substring.dropl isA (Substring.substring (inA, 3, 2))))
  val () = eqT ("Substring.taker/within-the-substring", (inA, 3, 2), fn () => Substring.base (Substring.taker isA (Substring.substring (inA, 3, 2))))
  val () = eqT ("Substring.dropr/within-the-substring", (inA, 3, 0), fn () => Substring.base (Substring.dropr isA (Substring.substring (inA, 3, 2))))
  val () = eqS ("Substring.dropl/whitespace", "text  ", fn () => Substring.string (Substring.dropl Char.isSpace (Substring.full "  text  ")))
  val () = eqS ("Substring.dropr/whitespace", "  text", fn () => Substring.string (Substring.dropr Char.isSpace (Substring.full "  text  ")))
  val () = eqS ("Substring.takel/digits", "123", fn () => Substring.string (Substring.takel Char.isDigit (Substring.full "123abc456")))
  val () = eqS ("Substring.taker/digits", "456", fn () => Substring.string (Substring.taker Char.isDigit (Substring.full "123abc456")))
  (* "The functions dropl and takel scan left to right (i.e., increasing
     character indices), while dropr and taker scan from the right." *)
  val () = eqCL ("Substring.takel/order", [#"a", #"b", #"X"],
                 fn () => let val (f, seen) = trace notX in ignore (Substring.takel f (Substring.substring ("XabXcdX", 1, 5))); seen () end)
  val () = eqCL ("Substring.dropl/order", [#"a", #"b", #"X"],
                 fn () => let val (f, seen) = trace notX in ignore (Substring.dropl f (Substring.substring ("XabXcdX", 1, 5))); seen () end)
  val () = eqCL ("Substring.taker/order", [#"d", #"c", #"X"],
                 fn () => let val (f, seen) = trace notX in ignore (Substring.taker f (Substring.substring ("XabXcdX", 1, 5))); seen () end)
  val () = eqCL ("Substring.dropr/order", [#"d", #"c", #"X"],
                 fn () => let val (f, seen) = trace notX in ignore (Substring.dropr f (Substring.substring ("XabXcdX", 1, 5))); seen () end)

  (* ---- position ----
     "let m be the size of s and let ss correspond to the substring (s', i, n).
     If there is a least index k >= i such that s = s'[k..k+m-1], then suff
     corresponds to (s', k, n+i-k) and pref corresponds to (s', i, k-i). If
     there is no such k, then suff is the empty substring corresponding to (s',
     i+n, 0) and pref corresponds to (s', i, n), i.e., all of ss."
     The occurrence has to lie within ss: "suff is the longest suffix of ss that
     has s as a prefix". (The precise wording forgets to say k+m <= i+n.) *)
  val () = eqTT ("Substring.position/first-occurrence", (("abcdcd", 0, 2), ("abcdcd", 2, 4)),
                 fn () => base2 (Substring.position "cd" (Substring.full "abcdcd")))
  val () = eqTT ("Substring.position/at-the-start", (("abcd", 0, 0), ("abcd", 0, 4)), fn () => base2 (Substring.position "ab" (Substring.full "abcd")))
  val () = eqTT ("Substring.position/at-the-end", (("abcd", 0, 2), ("abcd", 2, 2)), fn () => base2 (Substring.position "cd" (Substring.full "abcd")))
  val () = eqTT ("Substring.position/whole", (("abcd", 0, 0), ("abcd", 0, 4)), fn () => base2 (Substring.position "abcd" (Substring.full "abcd")))
  val () = eqTT ("Substring.position/one-character", (("abcd", 0, 3), ("abcd", 3, 1)), fn () => base2 (Substring.position "d" (Substring.full "abcd")))
  val () = eqTT ("Substring.position/overlapping-occurrences", (("baaa", 0, 1), ("baaa", 1, 3)), fn () => base2 (Substring.position "aa" (Substring.full "baaa")))
  val () = eqTT ("Substring.position/after-a-partial-match", (("aabaac", 0, 3), ("aabaac", 3, 3)),
                 fn () => base2 (Substring.position "aac" (Substring.full "aabaac")))
  val () = eqTT ("Substring.position/inside-a-string", (("xxabxxab", 3, 3), ("xxabxxab", 6, 2)),
                 fn () => base2 (Substring.position "ab" (Substring.substring ("xxabxxab", 3, 5))))
  val () = T.eq (T.pair (T.string, T.string)) ("Substring.position/strings", ("key", "=value=x"),
             fn () => let val (p, s) = Substring.position "=" (Substring.full "key=value=x") in (Substring.string p, Substring.string s) end)
  (* no occurrence *)
  val () = eqTT ("Substring.position/none", ((s8, 2, 4), (s8, 6, 0)), fn () => base2 (Substring.position "xy" (mid ())))
  val () = eqTT ("Substring.position/none-whole-string", (("abcd", 0, 4), ("abcd", 4, 0)), fn () => base2 (Substring.position "e" (Substring.full "abcd")))
  val () = eqTT ("Substring.position/none-longer-than-the-substring", ((s8, 2, 4), (s8, 6, 0)), fn () => base2 (Substring.position "cdefg" (mid ())))
  val () = eqTT ("Substring.position/none-only-before-the-substring", ((s8, 2, 4), (s8, 6, 0)), fn () => base2 (Substring.position "ab" (mid ())))
  val () = eqTT ("Substring.position/none-only-after-the-substring", ((s8, 2, 4), (s8, 6, 0)), fn () => base2 (Substring.position "gh" (mid ())))
  val () = eqTT ("Substring.position/none-starts-before-the-substring", ((s8, 2, 4), (s8, 6, 0)), fn () => base2 (Substring.position "bc" (mid ())))
  val () = eqTT ("Substring.position/none-ends-after-the-substring", ((s8, 2, 4), (s8, 6, 0)), fn () => base2 (Substring.position "fg" (mid ())))
  val () = eqTT ("Substring.position/none-in-empty", ((s8, 3, 0), (s8, 3, 0)), fn () => base2 (Substring.position "d" (nothing ())))
  val () = eqTT ("Substring.position/none-in-empty-string", (("", 0, 0), ("", 0, 0)), fn () => base2 (Substring.position "d" (Substring.full "")))
  (* the empty string: m = 0 and s'[i..i-1] is empty, so k = i *)
  val () = eqTT ("Substring.position/empty-string", ((s8, 2, 0), (s8, 2, 4)), fn () => base2 (Substring.position "" (mid ())))
  val () = eqTT ("Substring.position/empty-string-in-empty", ((s8, 3, 0), (s8, 3, 0)), fn () => base2 (Substring.position "" (nothing ())))
  val () = eqTT ("Substring.position/empty-string-in-empty-string", (("", 0, 0), ("", 0, 0)), fn () => base2 (Substring.position "" (Substring.full "")))
  val () = eqTT ("Substring.position/empty-string-at-the-end", ((s8, 8, 0), (s8, 8, 0)), fn () => base2 (Substring.position "" (Substring.extract (s8, 8, NONE))))

  (* ---- span ----
     "if we have
        val (s, i, n) = base ss
        val (s', i', n') = base ss'
      then span returns substring(s, i, (i'+n')-i) unless s <> s' or i'+n' < i,
      in which case it raises Span. Note that this does not preclude ss' from
      beginning to the left of ss, or ss from ending to the right of ss'." *)
  val () = eqT ("Substring.span/apart", (s8, 1, 6), fn () => Substring.base (Substring.span (Substring.substring (s8, 1, 2), Substring.substring (s8, 5, 2))))
  val () = eqT ("Substring.span/adjacent", (s8, 1, 4), fn () => Substring.base (Substring.span (Substring.substring (s8, 1, 2), Substring.substring (s8, 3, 2))))
  val () = eqT ("Substring.span/overlapping", (s8, 1, 4), fn () => Substring.base (Substring.span (Substring.substring (s8, 1, 3), Substring.substring (s8, 2, 3))))
  val () = eqT ("Substring.span/same", (s8, 2, 4), fn () => Substring.base (Substring.span (mid (), mid ())))
  val () = eqT ("Substring.span/whole", (s8, 0, 8), fn () => Substring.base (Substring.span (Substring.substring (s8, 0, 0), Substring.substring (s8, 8, 0))))
  val () = eqT ("Substring.span/empty-and-empty-same-place", (s8, 3, 0), fn () => Substring.base (Substring.span (nothing (), nothing ())))
  val () = eqT ("Substring.span/empty-to-empty", (s8, 3, 2), fn () => Substring.base (Substring.span (nothing (), Substring.substring (s8, 5, 0))))
  val () = eqT ("Substring.span/second-inside-first", (s8, 1, 3), fn () => Substring.base (Substring.span (Substring.substring (s8, 1, 6), Substring.substring (s8, 2, 2))))
  val () = eqT ("Substring.span/first-ends-to-the-right", (s8, 2, 2), fn () => Substring.base (Substring.span (Substring.substring (s8, 2, 6), Substring.substring (s8, 3, 1))))
  val () = eqT ("Substring.span/second-begins-to-the-left", (s8, 3, 2), fn () => Substring.base (Substring.span (Substring.substring (s8, 3, 4), Substring.substring (s8, 0, 5))))
  (* i'+n' = i: the second ends where the first starts, the span is empty *)
  val () = eqT ("Substring.span/second-ends-at-start-of-first", (s8, 3, 0), fn () => Substring.base (Substring.span (Substring.substring (s8, 3, 2), Substring.substring (s8, 1, 2))))
  val () = eqT ("Substring.span/empty-second-at-start-of-first", (s8, 3, 0), fn () => Substring.base (Substring.span (Substring.substring (s8, 3, 2), nothing ())))
  (* i'+n' < i *)
  val () = T.raises ("Substring.span/Span-second-ends-before-first", T.isSpan,
                     fn () => Substring.span (Substring.substring (s8, 3, 2), Substring.substring (s8, 0, 2)))
  val () = T.raises ("Substring.span/Span-second-ends-one-before-first", T.isSpan,
                     fn () => Substring.span (Substring.substring (s8, 3, 2), Substring.substring (s8, 1, 1)))
  val () = T.raises ("Substring.span/Span-empty-ones-in-the-wrong-order", T.isSpan,
                     fn () => Substring.span (Substring.substring (s8, 5, 0), Substring.substring (s8, 4, 0)))
  val () = T.raises ("Substring.span/Span-whole-string-ends", T.isSpan,
                     fn () => Substring.span (Substring.substring (s8, 8, 0), Substring.substring (s8, 0, 0)))
  (* s <> s' *)
  val () = T.raises ("Substring.span/Span-different-strings", T.isSpan,
                     fn () => Substring.span (Substring.substring (s8, 1, 2), Substring.substring ("abcdefgx", 5, 2)))
  val () = T.raises ("Substring.span/Span-different-strings-same-substrings", T.isSpan,
                     fn () => Substring.span (Substring.substring ("abcX", 0, 3), Substring.substring ("abcY", 0, 3)))
  val () = T.raises ("Substring.span/Span-string-and-its-prefix", T.isSpan,
                     fn () => Substring.span (Substring.substring ("abcd", 0, 1), Substring.substring ("abc", 1, 2)))
  val () = T.raises ("Substring.span/Span-empty-string-and-another", T.isSpan,
                     fn () => Substring.span (Substring.full "", Substring.substring ("a", 0, 0)))
  val () = T.raises ("Substring.span/Span-is-General.Span", fn General.Span => true | _ => false,
                     fn () => Substring.span (Substring.substring (s8, 3, 2), Substring.substring (s8, 0, 2)))
  (* "unless s <> s'" compares the strings ("the string equality test should be
     constant time ... first doing a pointer test and, only if that fails, then
     checking the strings character by character"): two equal strings built
     separately are one underlying string for span *)
  val () = eqT ("Substring.span/equal-strings-built-separately", (s8, 1, 6),
                fn () => let val copy = String.implode (List.rev (String.explode "hgfedcba"))
                         in Substring.base (Substring.span (Substring.substring (s8, 1, 2), Substring.substring (copy, 5, 2))) end)
  (* the page's example *)
  val url = "http://www.standardml.org/Basis/overview.html"
  fun protoAndHost url =
    let
      fun notc (c : char) = fn c' => c <> c'
      val (proto, rest) = Substring.splitl (notc #":") (Substring.full url)
      val host = Substring.takel (notc #"/") (Substring.triml 3 rest)
    in
      Substring.span (proto, host)
    end
  val () = eqT ("Substring.span/page-example", (url, 0, 25), fn () => Substring.base (protoAndHost url))
  val () = eqS ("Substring.span/page-example-string", "http://www.standardml.org", fn () => Substring.string (protoAndHost url))

  (* ---- translate ----
     "applies f to every character of s, from left to right, and returns the
     concatenation of the results" *)
  val () = eqS ("Substring.translate/basic", "c.d.e.f.", fn () => Substring.translate (fn c => String.implode [c, #"."]) (mid ()))
  val () = eqS ("Substring.translate/empty-results", "ce",
                fn () => Substring.translate (fn c => if c = #"d" orelse c = #"f" then "" else String.str c) (mid ()))
  val () = eqS ("Substring.translate/all-empty-results", "", fn () => Substring.translate (fn _ => "") (mid ()))
  val () = eqS ("Substring.translate/empty", "", fn () => Substring.translate (fn _ => "x") (nothing ()))
  val () = eqS ("Substring.translate/longer-results", "<c><d><e><f>", fn () => Substring.translate (fn c => "<" ^ String.str c ^ ">") (mid ()))
  val () = eqCL ("Substring.translate/order", [#"c", #"d", #"e", #"f"],
                 fn () => let val (f, seen) = trace String.str in ignore (Substring.translate f (mid ())); seen () end)

  (* ---- tokens, fields ----
     "A token is a non-empty maximal substring not containing any delimiter. A
     field is a (possibly empty) maximal substring of s not containing any
     delimiter." *)
  val bars = "|abc||def"
  (* "the substring "|abc||def" contains two tokens "abc" and "def", whereas it
     contains the four fields "", "abc", "" and "def"" *)
  val () = eqTL ("Substring.tokens/page-example", [(bars, 1, 3), (bars, 6, 3)], fn () => bases (Substring.tokens isBar (Substring.full bars)))
  val () = eqTL ("Substring.fields/page-example", [(bars, 0, 0), (bars, 1, 3), (bars, 5, 0), (bars, 6, 3)],
                 fn () => bases (Substring.fields isBar (Substring.full bars)))
  val () = T.eq (T.list T.string) ("Substring.tokens/page-example-strings", ["abc", "def"],
             fn () => List.map Substring.string (Substring.tokens isBar (Substring.full bars)))
  val () = T.eq (T.list T.string) ("Substring.fields/page-example-strings", ["", "abc", "", "def"],
             fn () => List.map Substring.string (Substring.fields isBar (Substring.full bars)))
  val () = eqTL ("Substring.tokens/empty", [], fn () => bases (Substring.tokens isBar (nothing ())))
  val () = eqTL ("Substring.fields/empty", [(s8, 3, 0)], fn () => bases (Substring.fields isBar (nothing ())))
  val () = eqTL ("Substring.tokens/empty-string", [], fn () => bases (Substring.tokens isBar (Substring.full "")))
  val () = eqTL ("Substring.fields/empty-string", [("", 0, 0)], fn () => bases (Substring.fields isBar (Substring.full "")))
  val () = eqTL ("Substring.tokens/no-delimiter", [(s8, 2, 4)], fn () => bases (Substring.tokens isBar (mid ())))
  val () = eqTL ("Substring.fields/no-delimiter", [(s8, 2, 4)], fn () => bases (Substring.fields isBar (mid ())))
  val () = eqTL ("Substring.tokens/delimiters-only", [], fn () => bases (Substring.tokens isBar (Substring.full "||")))
  val () = eqTL ("Substring.fields/delimiters-only", [("||", 0, 0), ("||", 1, 0), ("||", 2, 0)], fn () => bases (Substring.fields isBar (Substring.full "||")))
  val () = eqTL ("Substring.tokens/trailing-delimiter", [("a|b|", 0, 1), ("a|b|", 2, 1)], fn () => bases (Substring.tokens isBar (Substring.full "a|b|")))
  val () = eqTL ("Substring.fields/trailing-delimiter", [("a|b|", 0, 1), ("a|b|", 2, 1), ("a|b|", 4, 0)],
                 fn () => bases (Substring.fields isBar (Substring.full "a|b|")))
  (* delimiters around the substring are not part of it *)
  val around = "||a|bc||"
  val () = eqTL ("Substring.tokens/inside-a-string", [(around, 2, 1), (around, 4, 2)], fn () => bases (Substring.tokens isBar (Substring.substring (around, 2, 4))))
  val () = eqTL ("Substring.fields/inside-a-string", [(around, 2, 1), (around, 4, 2)], fn () => bases (Substring.fields isBar (Substring.substring (around, 2, 4))))
  val () = eqTL ("Substring.tokens/inside-a-string-with-delimiters", [(around, 2, 1), (around, 4, 2)],
                 fn () => bases (Substring.tokens isBar (Substring.substring (around, 1, 6))))
  val () = eqTL ("Substring.fields/inside-a-string-with-delimiters", [(around, 1, 0), (around, 2, 1), (around, 4, 2), (around, 7, 0)],
                 fn () => bases (Substring.fields isBar (Substring.substring (around, 1, 6))))
  val () = eqTL ("Substring.tokens/every-character-delimits", [], fn () => bases (Substring.tokens (fn _ => true) (Substring.substring (s8, 2, 2))))
  val () = eqTL ("Substring.fields/every-character-delimits", [(s8, 2, 0), (s8, 3, 0), (s8, 4, 0)],
                 fn () => bases (Substring.fields (fn _ => true) (Substring.substring (s8, 2, 2))))
  val () = T.eq (T.list T.string) ("Substring.tokens/whitespace", ["hello", "world"],
             fn () => List.map Substring.string (Substring.tokens Char.isSpace (Substring.full "  hello \t world\n")))
  val () = T.eq (T.list T.string) ("Substring.fields/commas", ["a", "b", "", "c", ""],
             fn () => List.map Substring.string (Substring.fields (fn c => c = #",") (Substring.full "a,b,,c,")))
  (* "from left to right" *)
  val () = eqCL ("Substring.tokens/order", [#"|", #"a", #"b", #"|", #"|", #"c"],
                 fn () => let val (f, seen) = trace isBar in ignore (Substring.tokens f (Substring.substring ("x|ab||cy", 1, 6))); seen () end)
  val () = eqCL ("Substring.fields/order", [#"|", #"a", #"b", #"|", #"|", #"c"],
                 fn () => let val (f, seen) = trace isBar in ignore (Substring.fields f (Substring.substring ("x|ab||cy", 1, 6))); seen () end)

  (* ---- app: "applies f to each character of s from left to right" ---- *)
  val () = eqCL ("Substring.app/order", [#"c", #"d", #"e", #"f"],
                 fn () => let val (f, seen) = trace (fn _ => ()) in Substring.app f (mid ()); seen () end)
  val () = eqCL ("Substring.app/empty", [], fn () => let val (f, seen) = trace (fn _ => ()) in Substring.app f (nothing ()); seen () end)
  val () = eqCL ("Substring.app/whole", String.explode s8,
                 fn () => let val (f, seen) = trace (fn _ => ()) in Substring.app f (Substring.full s8); seen () end)
  val () = T.eq T.unit ("Substring.app/returns-unit", (), fn () => Substring.app (fn _ => ()) (mid ()))

  (* ---- foldl, foldr: "List.foldl f a (explode s)", "List.foldr f a (explode s)" ---- *)
  val () = eqCL ("Substring.foldl/conses-reversed", [#"f", #"e", #"d", #"c"], fn () => Substring.foldl (op ::) [] (mid ()))
  val () = eqCL ("Substring.foldr/conses-in-order", [#"c", #"d", #"e", #"f"], fn () => Substring.foldr (op ::) [] (mid ()))
  val () = eqS ("Substring.foldl/appends", ">cdef", fn () => Substring.foldl (fn (c, a) => a ^ String.str c) ">" (mid ()))
  val () = eqS ("Substring.foldr/appends", ">fedc", fn () => Substring.foldr (fn (c, a) => a ^ String.str c) ">" (mid ()))
  (* digits of "123": ((0*10+1)*10+2)*10+3 from the left, ((0*10+3)*10+2)*10+1 from the right *)
  val () = eqI ("Substring.foldl/nonassociative", 123,
                fn () => Substring.foldl (fn (c, a) => 10 * a + (Char.ord c - 48)) 0 (Substring.substring ("9123", 1, 3)))
  val () = eqI ("Substring.foldr/nonassociative", 321,
                fn () => Substring.foldr (fn (c, a) => 10 * a + (Char.ord c - 48)) 0 (Substring.substring ("9123", 1, 3)))
  val () = eqI ("Substring.foldl/empty", 42, fn () => Substring.foldl (fn (_, a) => a + 1) 42 (nothing ()))
  val () = eqI ("Substring.foldr/empty", 42, fn () => Substring.foldr (fn (_, a) => a + 1) 42 (nothing ()))
  val () = eqI ("Substring.foldl/counts", 4, fn () => Substring.foldl (fn (_, a) => a + 1) 0 (mid ()))
  val () = eqI ("Substring.foldr/counts", 4, fn () => Substring.foldr (fn (_, a) => a + 1) 0 (mid ()))
  val () = eqCL ("Substring.foldl/order", [#"c", #"d", #"e", #"f"],
                 fn () => let val (f, seen) = trace (fn _ => ()) in Substring.foldl (fn (c, ()) => f c) () (mid ()); seen () end)
  val () = eqCL ("Substring.foldr/order", [#"f", #"e", #"d", #"c"],
                 fn () => let val (f, seen) = trace (fn _ => ()) in Substring.foldr (fn (c, ()) => f c) () (mid ()); seen () end)

  (* ---- long substrings: 100000 characters, a delimiter at every tenth ---- *)
  val long = 100000
  fun longString () = String.implode (List.tabulate (long + 2, fn i => if i mod 10 = 9 then #"|" else #"a"))
  fun longSub () = Substring.substring (longString (), 1, long)
  val () = eqI ("Substring.size/long", long, fn () => Substring.size (longSub ()))
  val () = eqI ("Substring.string/long", long, fn () => String.size (Substring.string (longSub ())))
  val () = eqI ("Substring.explode/long", long, fn () => List.length (Substring.explode (longSub ())))
  val () = eqI ("Substring.foldl/long", long, fn () => Substring.foldl (fn (_, n) => n + 1) 0 (longSub ()))
  val () = eqI ("Substring.foldr/long", long, fn () => Substring.foldr (fn (_, n) => n + 1) 0 (longSub ()))
  val () = eqI ("Substring.app/long", long, fn () => let val n = ref 0 in Substring.app (fn _ => n := !n + 1) (longSub ()); !n end)
  val () = eqI ("Substring.translate/long", 2 * long, fn () => String.size (Substring.translate (fn c => String.implode [c, c]) (longSub ())))
  (* the characters 1 to 100000 of the string: bars at 9, 19, ..., 99999, so 10000 bars *)
  val () = eqI ("Substring.fields/long", 10001, fn () => List.length (Substring.fields isBar (longSub ())))
  val () = eqI ("Substring.tokens/long", 10001, fn () => List.length (Substring.tokens isBar (longSub ())))
  val () = eqI ("Substring.splitl/long", long, fn () => Substring.size (#1 (Substring.splitl (fn _ => true) (longSub ()))))
  val () = eqI ("Substring.splitr/long", long, fn () => Substring.size (#2 (Substring.splitr (fn _ => true) (longSub ()))))
  val () = eqI ("Substring.concat/long", 2 * long, fn () => String.size (Substring.concat [longSub (), longSub ()]))
  val () = eqOrd ("Substring.compare/long", EQUAL, fn () => Substring.compare (longSub (), longSub ()))
  val () = eqB ("Substring.isSubstring/long", false, fn () => Substring.isSubstring "aaaaaaaaaa" (longSub ()))
  (* 100000 times a, then b: the only "ab" is at the very end *)
  fun longAB () = String.implode (List.tabulate (long + 1, fn i => if i = long then #"b" else #"a"))
  val () = eqI ("Substring.position/long", long - 1, fn () => Substring.size (#1 (Substring.position "ab" (Substring.full (longAB ())))))
  val () = eqI ("Substring.position/long-none", long, fn () => Substring.size (#1 (Substring.position "ab" (Substring.substring (longAB (), 0, long)))))
  val () = eqB ("Substring.isSuffix/long", true, fn () => Substring.isSuffix "aab" (Substring.full (longAB ())))

  (* ---- laws, on pseudo-random substrings ----
     The model works on triples (s, i, n) with String.size, String.sub and
     String.substring only. *)
  fun mString (s, i, n) = String.substring (s, i, n)
  fun mExplode (s, i, n) = List.tabulate (n, fn k => String.sub (s, i + k))
  (* the number of characters at the left (right) end that satisfy f *)
  fun mRunL f (s, i, n) = let fun go k = if k < n andalso f (String.sub (s, i + k)) then go (k + 1) else k in go 0 end
  fun mRunR f (s, i, n) = let fun go k = if k < n andalso f (String.sub (s, i + n - 1 - k)) then go (k + 1) else k in go 0 end
  fun mSplitl f (t as (s, i, n)) = let val k = mRunL f t in ((s, i, k), (s, i + k, n - k)) end
  fun mSplitr f (t as (s, i, n)) = let val k = mRunR f t in ((s, i, n - k), (s, i + n - k, k)) end
  (* the least k >= i with s[k..k+m-1] = p and k + m <= i + n *)
  fun mFind p (s, i, n) =
    let val m = String.size p
        fun go k = if k + m > i + n then NONE else if String.substring (s, k, m) = p then SOME k else go (k + 1)
    in go i end
  fun mPosition p (t as (s, i, n)) =
    case mFind p t of
      SOME k => ((s, i, k - i), (s, k, n + i - k))
    | NONE => ((s, i, n), (s, i + n, 0))
  fun mFields f (s, i, n) =
    let fun go (k, start, acc) =
          if k = i + n then List.rev ((s, start, k - start) :: acc)
          else if f (String.sub (s, k)) then go (k + 1, k + 1, (s, start, k - start) :: acc)
          else go (k + 1, start, acc)
    in go (i, i, []) end
  fun mTokens f t = List.filter (fn (_, _, n) => n > 0) (mFields f t)
  fun mCollate cmp ((s, i, n), (s', i', n')) =
    let fun go k = if k = n andalso k = n' then EQUAL
                   else if k = n then LESS
                   else if k = n' then GREATER
                   else case cmp (String.sub (s, i + k), String.sub (s', i' + k)) of EQUAL => go (k + 1) | r => r
    in go 0 end
  val mCompare = mCollate (fn (x, y) => Int.compare (Char.ord x, Char.ord y))

  fun randomWord n = String.implode (List.tabulate (T.range (0, n), fn _ => T.oneOf [#"a", #"b", #"|"]))
  fun randomTriple s =
    let val i = T.range (0, String.size s)
        val n = T.range (0, String.size s - i)
    in (s, i, n) end
  val mk = Substring.substring

  val () = T.seed 31
  val () = T.repeat (40, fn k =>
    let
      val no = Int.toString k
      val s = randomWord 12
      val t as (_, i, n) = randomTriple s
      val u = randomTriple s                      (* in the same string *)
      val (_, ui, un) = u
      val v = randomTriple (randomWord 12)        (* in another one *)
      val p = randomWord 3
      val m = String.size p
      val f = T.oneOf [isA, isBar, fn c => c <> #"b", fn _ => true, fn _ => false]
      val j = T.range (0, n)
      val l = T.range (0, n - j)
      val far = n + T.range (1, 5)
      val dup = fn c => if c = #"a" then "" else String.implode [c, c]
    in
      eqT ("Substring.base/law-" ^ no, t, fn () => Substring.base (mk t));
      eqS ("Substring.string/law-" ^ no, mString t, fn () => Substring.string (mk t));
      eqT ("Substring.extract/law-SOME-" ^ no, t, fn () => Substring.base (Substring.extract (s, i, SOME n)));
      eqT ("Substring.extract/law-NONE-" ^ no, (s, i, String.size s - i), fn () => Substring.base (Substring.extract (s, i, NONE)));
      eqT ("Substring.full/law-" ^ no, (s, 0, String.size s), fn () => Substring.base (Substring.full s));
      eqI ("Substring.size/law-" ^ no, n, fn () => Substring.size (mk t));
      eqB ("Substring.isEmpty/law-" ^ no, n = 0, fn () => Substring.isEmpty (mk t));
      eqCL ("Substring.explode/law-" ^ no, mExplode t, fn () => Substring.explode (mk t));
      eqCL ("Substring.sub/law-" ^ no, mExplode t, fn () => List.tabulate (n, fn x => Substring.sub (mk t, x)));
      T.raises ("Substring.sub/law-Subscript-" ^ no, T.isSubscript, fn () => Substring.sub (mk t, n));
      eqG ("Substring.getc/law-" ^ no, if n = 0 then NONE else SOME (String.sub (s, i), (s, i + 1, n - 1)),
           fn () => Option.map (fn (c, r) => (c, Substring.base r)) (Substring.getc (mk t)));
      eqCO ("Substring.first/law-" ^ no, if n = 0 then NONE else SOME (String.sub (s, i)), fn () => Substring.first (mk t));
      eqT ("Substring.triml/law-" ^ no, (s, i + j, n - j), fn () => Substring.base (Substring.triml j (mk t)));
      eqT ("Substring.trimr/law-" ^ no, (s, i, n - j), fn () => Substring.base (Substring.trimr j (mk t)));
      T.check ("Substring.triml/law-beyond-size-" ^ no, fn () => emptyWithin (Substring.triml far (mk t), t));
      T.check ("Substring.trimr/law-beyond-size-" ^ no, fn () => emptyWithin (Substring.trimr far (mk t), t));
      eqT ("Substring.slice/law-SOME-" ^ no, (s, i + j, l), fn () => Substring.base (Substring.slice (mk t, j, SOME l)));
      eqT ("Substring.slice/law-NONE-" ^ no, (s, i + j, n - j), fn () => Substring.base (Substring.slice (mk t, j, NONE)));
      T.raises ("Substring.slice/law-Subscript-" ^ no, T.isSubscript, fn () => Substring.slice (mk t, j, SOME (n - j + 1)));
      eqTT ("Substring.splitAt/law-" ^ no, ((s, i, j), (s, i + j, n - j)), fn () => base2 (Substring.splitAt (mk t, j)));
      T.raises ("Substring.splitAt/law-Subscript-" ^ no, T.isSubscript, fn () => Substring.splitAt (mk t, far));
      eqS ("Substring.concat/law-" ^ no, mString t ^ mString v ^ mString u ^ mString t,
           fn () => Substring.concat [mk t, mk v, mk u, mk t]);
      eqS ("Substring.concatWith/law-" ^ no, mString t ^ p ^ mString v ^ p ^ mString u,
           fn () => Substring.concatWith p [mk t, mk v, mk u]);
      eqB ("Substring.isPrefix/law-" ^ no, m <= n andalso String.substring (s, i, m) = p, fn () => Substring.isPrefix p (mk t));
      eqB ("Substring.isSuffix/law-" ^ no, m <= n andalso String.substring (s, i + n - m, m) = p, fn () => Substring.isSuffix p (mk t));
      (* the label tells the empty string in an empty substring from the other draws *)
      eqB ("Substring.isSubstring/law-" ^ (if m = 0 andalso n = 0 then "empty-of-empty-" else "") ^ no,
           Option.isSome (mFind p t), fn () => Substring.isSubstring p (mk t));
      eqOrd ("Substring.compare/law-" ^ no, mCompare (t, v), fn () => Substring.compare (mk t, mk v));
      eqOrd ("Substring.compare/law-same-string-" ^ no, mCompare (t, u), fn () => Substring.compare (mk t, mk u));
      eqOrd ("Substring.compare/law-antisymmetric-" ^ no, mCompare (v, t), fn () => Substring.compare (mk v, mk t));
      eqOrd ("Substring.collate/law-" ^ no, mCompare (t, v), fn () => Substring.collate Char.compare (mk t, mk v));
      eqOrd ("Substring.collate/law-reversed-" ^ no, mCollate reversed (t, v), fn () => Substring.collate reversed (mk t, mk v));
      eqTT ("Substring.splitl/law-" ^ no, mSplitl f t, fn () => base2 (Substring.splitl f (mk t)));
      eqTT ("Substring.splitr/law-" ^ no, mSplitr f t, fn () => base2 (Substring.splitr f (mk t)));
      eqT ("Substring.takel/law-" ^ no, #1 (mSplitl f t), fn () => Substring.base (Substring.takel f (mk t)));
      eqT ("Substring.dropl/law-" ^ no, #2 (mSplitl f t), fn () => Substring.base (Substring.dropl f (mk t)));
      eqT ("Substring.taker/law-" ^ no, #2 (mSplitr f t), fn () => Substring.base (Substring.taker f (mk t)));
      eqT ("Substring.dropr/law-" ^ no, #1 (mSplitr f t), fn () => Substring.base (Substring.dropr f (mk t)));
      eqTT ("Substring.position/law-" ^ no, mPosition p t, fn () => base2 (Substring.position p (mk t)));
      eqT ("Substring.position/law-span-restores-" ^ no, t, fn () => Substring.base (Substring.span (Substring.position p (mk t))));
      (if ui + un < i
       then T.raises ("Substring.span/law-" ^ no, T.isSpan, fn () => Substring.span (mk t, mk u))
       else eqT ("Substring.span/law-" ^ no, (s, i, ui + un - i), fn () => Substring.base (Substring.span (mk t, mk u))));
      eqT ("Substring.span/law-restores-splitl-" ^ no, t, fn () => Substring.base (Substring.span (Substring.splitl f (mk t))));
      eqT ("Substring.span/law-restores-splitr-" ^ no, t, fn () => Substring.base (Substring.span (Substring.splitr f (mk t))));
      eqT ("Substring.span/law-restores-splitAt-" ^ no, t, fn () => Substring.base (Substring.span (Substring.splitAt (mk t, j))));
      eqT ("Substring.span/law-first-to-last-field-" ^ no, t,
           fn () => let val fs = Substring.fields isBar (mk t) in Substring.base (Substring.span (List.hd fs, List.last fs)) end);
      eqS ("Substring.translate/law-" ^ no, String.concat (List.map dup (mExplode t)), fn () => Substring.translate dup (mk t));
      eqTL ("Substring.fields/law-" ^ no, mFields isBar t, fn () => bases (Substring.fields isBar (mk t)));
      eqTL ("Substring.tokens/law-" ^ no, mTokens isBar t, fn () => bases (Substring.tokens isBar (mk t)));
      eqTL ("Substring.fields/law-other-delimiters-" ^ no, mFields f t, fn () => bases (Substring.fields f (mk t)));
      eqTL ("Substring.tokens/law-other-delimiters-" ^ no, mTokens f t, fn () => bases (Substring.tokens f (mk t)));
      eqS ("Substring.fields/law-concatWith-restores-" ^ no, mString t, fn () => Substring.concatWith "|" (Substring.fields isBar (mk t)));
      eqCL ("Substring.app/law-" ^ no, mExplode t,
            fn () => let val (g, seen) = trace (fn _ => ()) in Substring.app g (mk t); seen () end);
      eqCL ("Substring.foldl/law-" ^ no, List.foldl (op ::) [] (mExplode t), fn () => Substring.foldl (op ::) [] (mk t));
      eqCL ("Substring.foldr/law-" ^ no, List.foldr (op ::) [] (mExplode t), fn () => Substring.foldr (op ::) [] (mk t))
    end)
end
