(* Checks of a structure with signature BIT_FLAGS. Expected values follow
   https://smlfamily.github.io/Basis/bit-flags.html.

     structure R = TestBitFlagsFn (structure F = Posix.IO.FD val name = "Posix.IO.FD" val named = [("cloexec", Posix.IO.FD.cloexec)])

   needs spec-sigs/BIT_FLAGS.sml. The labels are name ^ ".member/case".
   named: the flags the structure names, with their names. Nothing is assumed
   of their bits (a named flag may have several, like Posix.FileSys.S.irwxu,
   or none, like Posix.TTY.C.cs5) beyond what the page says: "flags [] denotes
   the empty set", "intersect [] denotes all", clear is "the set difference"
   and "equivalent to fromWord(SysWord.andb(SysWord.notb (toWord fl1), toWord
   fl2))", allSet "tests for inclusion", anySet "for non-empty
   intersection", all "represents the union of all flags", "fromWord o toWord
   must be the identity function, and toWord o fromWord must be equivalent to
   fn w => SysWord.andb(w, toWord all)". toWord gives the bits of a set, so
   the empty set is 0w0 and a union is the orb of the words. Other flags than
   the named ones come from fromWord of pseudo-random words, with bits at
   every place of SysWord.word. *)
functor TestBitFlagsFn (structure F : SPEC_BIT_FLAGS
                        val name : string
                        val named : (string * F.flags) list) =
struct
  fun lab s = name ^ "." ^ s
  fun showW x = "0wx" ^ SysWord.toString x
  fun showF f = showW (F.toWord f)
  val eqW = T.eq showW
  val eqF = T.eq showF
  val eqB = T.eq T.bool
  (* the names of the named flags for which p does not hold, and of the pairs
     (a, b) of them for which q does not *)
  val noneFail = T.eq (T.list T.string)
  fun failing p = List.map #1 (List.filter (fn (_, c) => not (p c)) named)
  fun failingPairs q =
    List.concat (List.map (fn (n1, a) =>
                             List.map (fn (n2, _) => n1 ^ "," ^ n2)
                                      (List.filter (fn (_, b) => not (q (a, b))) named))
                          named)
  (* randomWord (): 30 pseudo-random bits, 0, 16 or 32 places up;
     randomFlags (): the flags of all among them, so that only the checks of
     fromWord depend on what fromWord does with the others. holdsRandom p:
     p (a, b) for 60 pairs of such flags. *)
  fun randomWord () = SysWord.<< (SysWord.fromInt (T.rand ()), Word.fromInt (T.oneOf [0, 16, 32]))
  fun randomFlags () = F.fromWord (SysWord.andb (randomWord (), F.toWord F.all))
  fun holdsRandom p =
    let
      fun go 0 = true
        | go n = p (randomFlags (), randomFlags ()) andalso go (n - 1)
    in go 60 end
  (* inclusion and intersection, from the words: the checks of the other
     members do not rely on allSet and anySet *)
  fun includes (a, b) = SysWord.andb (F.toWord a, F.toWord b) = F.toWord a
  fun meets (a, b) = SysWord.andb (F.toWord a, F.toWord b) <> 0w0
  val empty = F.flags []
  val () = T.seed 1789

  (* ---- toWord ---- *)
  val () = eqW (lab "toWord/empty-set-is-zero", 0w0, fn () => F.toWord (F.flags []))
  val () = noneFail (lab "toWord/union-is-orb", [],
                     fn () => failingPairs (fn (a, b) => F.toWord (F.flags [a, b]) = SysWord.orb (F.toWord a, F.toWord b)))
  val () = noneFail (lab "toWord/fromWord-of-named", [],
                     fn () => failing (fn c => F.toWord (F.fromWord (F.toWord c)) = F.toWord c))
  val () = eqB (lab "toWord/union-is-orb-random", true,
                fn () => holdsRandom (fn (a, b) => F.toWord (F.flags [a, b]) = SysWord.orb (F.toWord a, F.toWord b)))

  (* ---- fromWord ---- *)
  val () = noneFail (lab "fromWord/inverts-toWord-on-named", [],
                     fn () => failing (fn c => F.fromWord (F.toWord c) = c))
  val () = eqB (lab "fromWord/inverts-toWord-on-all-and-empty", true,
                fn () => F.fromWord (F.toWord F.all) = F.all andalso F.fromWord (F.toWord empty) = empty)
  val () = eqB (lab "fromWord/inverts-toWord-random", true,
                fn () => holdsRandom (fn (a, _) => F.fromWord (F.toWord a) = a))
  val () = eqF (lab "fromWord/zero-is-empty", empty, fn () => F.fromWord 0w0)
  val () = eqW (lab "fromWord/word-of-all", F.toWord F.all, fn () => F.toWord (F.fromWord (F.toWord F.all)))
  (* "toWord o fromWord must be equivalent to fn w => SysWord.andb(w, toWord
     all)", also for bits that no flag has *)
  val () = eqW (lab "fromWord/bits-beyond-all", F.toWord F.all, fn () => F.toWord (F.fromWord (SysWord.notb 0w0)))
  val () = eqB (lab "fromWord/random-words-beyond-all", true,
                fn () => let
                           fun go 0 = true
                             | go n = let val x = randomWord ()
                                      in F.toWord (F.fromWord x) = SysWord.andb (x, F.toWord F.all) andalso go (n - 1) end
                         in go 60 end)

  (* ---- all ---- *)
  val () = noneFail (lab "all/contains-named", [], fn () => failing (fn c => includes (c, F.all)))
  val () = noneFail (lab "all/union-with-named", [], fn () => failing (fn c => F.flags [F.all, c] = F.all))
  val () = eqB (lab "fromWord/result-within-all", true,
                fn () => let
                           fun go 0 = true
                             | go n = includes (F.fromWord (randomWord ()), F.all) andalso go (n - 1)
                         in go 60 end)
  val () = eqB (lab "all/not-empty", true, fn () => F.all <> empty orelse List.all (fn (_, c) => c = empty) named)

  (* ---- flags ---- *)
  val () = eqW (lab "flags/empty-list", 0w0, fn () => F.toWord (F.flags []))
  val () = noneFail (lab "flags/singleton", [], fn () => failing (fn c => F.flags [c] = c))
  val () = noneFail (lab "flags/idempotent", [], fn () => failing (fn c => F.flags [c, c, empty] = c))
  val () = noneFail (lab "flags/commutative", [], fn () => failingPairs (fn (a, b) => F.flags [a, b] = F.flags [b, a]))
  val () = eqB (lab "flags/three", true,
                fn () => holdsRandom (fn (a, b) =>
                                        let val c = randomFlags ()
                                        in F.toWord (F.flags [a, b, c])
                                           = SysWord.orb (F.toWord a, SysWord.orb (F.toWord b, F.toWord c))
                                        end))
  val () = eqF (lab "flags/of-all-named", F.fromWord (List.foldl SysWord.orb 0w0 (List.map (F.toWord o #2) named)),
                fn () => F.flags (List.map #2 named))

  (* ---- intersect ---- *)
  val () = eqF (lab "intersect/empty-list-is-all", F.all, fn () => F.intersect [])
  val () = noneFail (lab "intersect/singleton", [], fn () => failing (fn c => F.intersect [c] = c))
  val () = noneFail (lab "intersect/with-empty", [], fn () => failing (fn c => F.intersect [c, empty] = empty))
  val () = noneFail (lab "intersect/with-all", [], fn () => failing (fn c => F.intersect [F.all, c] = c))
  val () = noneFail (lab "intersect/is-andb", [],
                     fn () => failingPairs (fn (a, b) => F.toWord (F.intersect [a, b]) = SysWord.andb (F.toWord a, F.toWord b)))
  val () = eqB (lab "intersect/is-andb-random", true,
                fn () => holdsRandom (fn (a, b) => F.toWord (F.intersect [a, b]) = SysWord.andb (F.toWord a, F.toWord b)))
  val () = eqB (lab "intersect/three", true,
                fn () => holdsRandom (fn (a, b) =>
                                        let val c = randomFlags ()
                                        in F.intersect [a, b, c] = F.intersect [F.intersect [a, b], c] end))

  (* ---- clear ---- *)
  fun clearByWords (a, b) = F.fromWord (SysWord.andb (SysWord.notb (F.toWord a), F.toWord b))
  val () = noneFail (lab "clear/definition", [], fn () => failingPairs (fn (a, b) => F.clear (a, b) = clearByWords (a, b)))
  val () = eqB (lab "clear/definition-random", true, fn () => holdsRandom (fn (a, b) => F.clear (a, b) = clearByWords (a, b)))
  val () = noneFail (lab "clear/self-is-empty", [], fn () => failing (fn c => F.clear (c, c) = empty))
  val () = noneFail (lab "clear/empty-clears-nothing", [], fn () => failing (fn c => F.clear (empty, c) = c))
  val () = noneFail (lab "clear/all-clears-everything", [], fn () => failing (fn c => F.clear (F.all, c) = empty))
  val () = eqB (lab "clear/is-set-difference", true,
                fn () => holdsRandom (fn (a, b) => let val d = F.clear (a, b)
                                                   in includes (d, b) andalso not (meets (a, d))
                                                      andalso F.flags [d, F.intersect [a, b]] = b end))
  (* "the set of those flags in fl2 that are not set in fl1" *)
  val () = eqF (lab "clear/order-of-arguments", F.all, fn () => F.clear (empty, F.all))

  (* ---- allSet ---- *)
  val () = noneFail (lab "allSet/empty-in-anything", [], fn () => failing (fn c => F.allSet (empty, c)))
  val () = noneFail (lab "allSet/reflexive", [], fn () => failing (fn c => F.allSet (c, c)))
  val () = noneFail (lab "allSet/in-union", [], fn () => failingPairs (fn (a, b) => F.allSet (a, F.flags [b, a])))
  val () = noneFail (lab "allSet/is-inclusion", [], fn () => failingPairs (fn (a, b) => F.allSet (a, b) = includes (a, b)))
  val () = eqB (lab "allSet/is-inclusion-random", true, fn () => holdsRandom (fn (a, b) => F.allSet (a, b) = includes (a, b)))
  val () = eqB (lab "allSet/order-of-arguments", true,
                fn () => List.all (fn (_, c) => F.allSet (c, F.all) andalso
                                                (F.allSet (F.all, c) = (c = F.all))) named)

  (* ---- anySet ---- *)
  val () = noneFail (lab "anySet/empty-meets-nothing", [],
                     fn () => failing (fn c => not (F.anySet (empty, c)) andalso not (F.anySet (c, empty))))
  val () = noneFail (lab "anySet/nonempty-meets-itself", [], fn () => failing (fn c => F.anySet (c, c) = (c <> empty)))
  val () = noneFail (lab "anySet/is-nonempty-intersection", [],
                     fn () => failingPairs (fn (a, b) => F.anySet (a, b) = meets (a, b)))
  val () = eqB (lab "anySet/is-nonempty-intersection-random", true,
                fn () => holdsRandom (fn (a, b) => F.anySet (a, b) = meets (a, b)))
  val () = eqB (lab "anySet/symmetric-random", true, fn () => holdsRandom (fn (a, b) => F.anySet (a, b) = F.anySet (b, a)))
end
