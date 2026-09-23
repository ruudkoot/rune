(* requires: Runtime Array Char List String *)
(* Runtime (signature RUNTIME, Rune's own): the counters the VM keeps for the
   program it is running. No other SML system counts any of this, and
   lib/basis/runtime.sml is `host = no` in the MANIFEST, so this file runs on
   Rune alone.

   The numbers themselves are not checked. They depend on everything the
   program did before reaching this file, and on the library, which changes.
   What is checked is what the documentation promises of them: that they
   grow, that they stay within one another, and that an allocation of a known
   shape moves them by exactly what that shape costs. *)
structure TestRuntime =
struct
  val eqI = T.eq T.int

  (* kept in a ref so that nothing allocated below can be taken for unused *)
  val keep : int list ref = ref []

  (* What f allocated, together with what measuring it costs -- one `stats`
     record, since the counters are read before the record that carries them
     is built. Every check below subtracts one measurement from another, so
     that constant cancels and what is left is f's own. *)
  fun allocated f =
    let
      val a = Runtime.stats ()
      val () = f ()
      val b = Runtime.stats ()
    in
      {bytes = #bytes b - #bytes a, objects = #objects b - #objects a}
    end

  fun nothing () = allocated (fn () => keep := !keep)

  val () = T.check ("Runtime.stats/instructions-grow",
                    fn () =>
                      let val a = #instructions (Runtime.stats ())
                      in a < #instructions (Runtime.stats ()) end)

  (* A list cell is two objects -- the pair of head and tail, and the
     constructor around it -- and 64 bytes (docs/runtime.md). *)
  val () = eqI ("Runtime.stats/bytes-count-a-list-cell", 64,
                fn () => #bytes (allocated (fn () => keep := 1 :: !keep)) - #bytes (nothing ()))
  val () = eqI ("Runtime.stats/objects-count-a-list-cell", 2,
                fn () => #objects (allocated (fn () => keep := 1 :: !keep)) - #objects (nothing ()))

  (* A ref is the smallest object there is: an 8-byte header and a payload
     rounded up to 16. *)
  val () = eqI ("Runtime.stats/bytes-count-the-smallest-object", 24,
                fn () => #bytes (allocated (fn () => ignore (ref 7))) - #bytes (nothing ()))
  val () = eqI ("Runtime.stats/objects-count-the-smallest-object", 1,
                fn () => #objects (allocated (fn () => ignore (ref 7))) - #objects (nothing ()))

  val () = T.check ("Runtime.stats/live-is-within-the-semispace",
                    fn () => let val s = Runtime.stats () in #live s <= #heapSize s end)
  val () = T.check ("Runtime.stats/bytes-cover-what-is-in-use",
                    fn () => let val s = Runtime.stats () in #bytes s >= #live s end)
  val () = T.check ("Runtime.stats/collections-and-objects-are-not-negative",
                    fn () => let val s = Runtime.stats ()
                             in #collections s >= 0 andalso #objects s > 0 end)

  (* ---- collect *)

  val () = eqI ("Runtime.collect/makes-one-collection", 1,
                fn () =>
                  let val a = #collections (Runtime.stats ())
                      val () = Runtime.collect ()
                  in #collections (Runtime.stats ()) - a end)

  (* What a collection is for: a thousand cells the semispace holds while they
     are reachable and does not once they are not. *)
  val () = T.check ("Runtime.collect/drops-what-is-unreachable",
                    fn () =>
                      let
                        fun many (0, acc) = acc
                          | many (n, acc) = many (n - 1, n :: acc)
                        val () = keep := many (1000, [])
                        val () = Runtime.collect ()
                        val held = #live (Runtime.stats ())
                        val () = keep := []
                        val () = Runtime.collect ()
                        val freed = #live (Runtime.stats ())
                      in
                        held - freed >= 1000 * 64
                      end)

  val () = T.check ("Runtime.collect/identity-survives-it",
                    fn () =>
                      let val r = ref 5
                          val s = r
                          val () = Runtime.collect ()
                      in Runtime.same (r, s) andalso !r = 5 end)

  (* ---- same *)

  val () = T.check ("Runtime.same/a-ref-is-itself",
                    fn () => let val r = ref 0 in Runtime.same (r, r) end)
  val () = T.check ("Runtime.same/two-equal-refs-are-two",
                    fn () => not (Runtime.same (ref 0, ref 0)))
  val () = T.check ("Runtime.same/agrees-with-equality-on-refs",
                    fn () =>
                      let val r = ref 0
                          val s = ref 0
                      in Runtime.same (r, s) = (r = s) andalso Runtime.same (r, r) = (r = r) end)
  val () = T.check ("Runtime.same/an-array-is-itself",
                    fn () =>
                      let val a = Array.array (3, 0)
                      in Runtime.same (a, a) andalso not (Runtime.same (a, Array.array (3, 0))) end)
  (* a value that is not in the heap has no identity, so the values are
     compared: two reals that are equal to `=` are not the same real *)
  val () = T.check ("Runtime.same/compares-what-is-not-in-the-heap",
                    fn () => Runtime.same (1, 1) andalso not (Runtime.same (1, 2))
                             andalso Runtime.same ((), ()) andalso not (Runtime.same (0.0, ~0.0)))
  (* where `=` is not available at all *)
  val () = T.check ("Runtime.same/works-where-equality-does-not",
                    fn () => let val f = fn x : int => x + 1 in Runtime.same (f, f) end)

  (* ---- version *)

  val () = T.check ("Runtime.version/is-numbers-separated-by-dots",
                    fn () =>
                      let val parts = String.fields (fn c => c = #".") Runtime.version
                      in List.length parts = 3
                         andalso List.all (fn q => q <> "" andalso List.all Char.isDigit (String.explode q))
                                          parts
                      end)
end
