(* Division by a constant (functors-units M1): tier 2 divides by a literal
   with no division -- a power of two by shifts and masks, any other by the
   high half of a product with a magic number and the floor's or the
   truncation's fix-up -- and keeps the general path for 0 and ~1. Each
   operation by each literal of a table is checked against the same
   operation by the divisor read from a ref, which no tier knows, on the
   edges, the multiples of the divisor around them and pseudo-random
   dividends, values and exceptions alike: int, word, Int64.int and
   Word64.word, whose literals past 63 bits are boxes. So are a divisor
   that reaches the division through a join, a case, a loop and a
   handler, a register that held a literal and holds something else in
   the same run, and Pickle.hash's loop. The checksum is of every result of
   the literal divisions, which every mode of the JIT must give as the
   interpreter does (--jit=off: the C primitives). Generated, from E7's
   test; make test-int64 runs it at --int-bits=64. *)
val maxInt = valOf Int.maxInt
val minInt = valOf Int.minInt
val maxWord = Word.notb 0w0
val maxI64 = valOf Int64.maxInt
val minI64 = valOf Int64.minInt
val maxW64 = Word64.notb 0w0
datatype 'a r = V of 'a | E of string
fun run f n = V (f n) handle Div => E "Div" | Overflow => E "Overflow"
val checks = ref 0
val fails = ref 0
(* the checksum, in Word: no division *)
val sum = ref (0w0 : word)
fun mixw w = sum := !sum * 0w1000003 + w
fun mix toWord (V x) = mixw (toWord x)
  | mix _ (E s) = mixw (Word.fromInt (size s))
val seed = ref (0wx2545F4914F6CDD1D : Word64.word)
fun next () =
  let val x = !seed
      val x = Word64.xorb (x, Word64.<< (x, 0w13))
      val x = Word64.xorb (x, Word64.>> (x, 0w7))
      val x = Word64.xorb (x, Word64.<< (x, 0w17))
  in seed := x; x end
fun shift () = Word.andb (Word.fromLarge (next ()), 0w63)
fun add (l, f) = (f () :: l) handle Overflow => l
fun range (a, b) = if a > b then [] else a :: range (a + 1, b)
fun ints (c : int) =
  let
    val l = [0, 1, ~1, 2, ~2, 3, ~3, maxInt, maxInt - 1, maxInt - 2, minInt, minInt + 1, minInt + 2]
    val l = List.foldl (fn (k, l) => List.foldl (fn (e, l) => add (l, fn () => c * k + e)) l (range (~2, 2))) l (range (~12, 12))
    val l = if c = 0 then l else
      List.foldl (fn (e, l) => add (add (l, fn () => Int.quot (maxInt, c) * c + e), fn () => Int.quot (minInt, c) * c + e))
                 l (range (~3, 3))
  in List.foldl (fn (_, l) => let val w = Word.fromLarge (next ()) in Word.toIntX w :: Word.toIntX (Word.~>> (w, shift ())) :: l end)
                l (range (1, 100))
  end
fun words (c : word) =
  let
    val l = [0w0, 0w1, 0w2, 0w3, maxWord, maxWord - 0w1, maxWord - 0w2, Word.>> (maxWord, 0w1), Word.>> (maxWord, 0w1) + 0w1]
    val l = List.foldl (fn (k, l) => List.foldl (fn (e, l) => c * Word.fromInt k + Word.fromInt e :: l) l (range (0, 4))) l (range (0, 24))
    val l = if c = 0w0 then l else
      List.foldl (fn (k, l) => List.foldl (fn (e, l) => (maxWord div c - Word.fromInt k) * c + Word.fromInt e :: l) l (range (0, 4)))
                 l (range (0, 8))
  in List.foldl (fn (_, l) => let val w = Word.fromLarge (next ()) in w :: Word.>> (w, shift ()) :: l end) l (range (1, 100)) end
fun int64s (c : Int64.int) =
  let
    val l = [0, 1, ~1, 2, ~2, 3, ~3, maxI64, maxI64 - 1, maxI64 - 2, minI64, minI64 + 1, minI64 + 2] : Int64.int list
    val l = List.foldl (fn (k, l) => List.foldl (fn (e, l) => add (l, fn () => c * Int64.fromInt k + Int64.fromInt e)) l (range (~2, 2)))
                       l (range (~12, 12))
    val l = if c = 0 then l else
      List.foldl (fn (e, l) => add (add (l, fn () => Int64.quot (maxI64, c) * c + Int64.fromInt e),
                                    fn () => Int64.quot (minI64, c) * c + Int64.fromInt e))
                 l (range (~3, 3))
    fun i64 w = Int64.fromLarge (Word64.toLargeIntX w)
  in List.foldl (fn (_, l) => let val w = next () in i64 w :: i64 (Word64.~>> (w, shift ())) :: l end) l (range (1, 100)) end
fun word64s (c : Word64.word) =
  let
    val l = [0w0, 0w1, 0w2, 0w3, maxW64, maxW64 - 0w1, maxW64 - 0w2, Word64.>> (maxW64, 0w1), Word64.>> (maxW64, 0w1) + 0w1]
    val l = List.foldl (fn (k, l) => List.foldl (fn (e, l) => c * Word64.fromInt k + Word64.fromInt e :: l) l (range (0, 4)))
                       l (range (0, 24))
    val l = if c = 0w0 then l else
      List.foldl (fn (k, l) => List.foldl (fn (e, l) => (maxW64 div c - Word64.fromInt k) * c + Word64.fromInt e :: l) l (range (0, 4)))
                 l (range (0, 8))
  in List.foldl (fn (_, l) => let val w = next () in w :: Word64.>> (w, shift ()) :: l end) l (range (1, 100)) end
fun show s (V x) = s x
  | show _ (E e) = e
(* the literal division fast and the ref's slow on every dividend of ns *)
fun check (name, cs, s : ''a -> string, toWord, ns : ''a list) (fast : ''a -> ''a, slow) =
  List.app (fn n =>
    let val a = run fast n
        val b = run slow n
    in checks := !checks + 1; mix toWord a;
       if a = b then ()
       else (fails := !fails + 1;
             if !fails <= 30 then print ("FAIL " ^ name ^ " " ^ s n ^ " by " ^ cs ^ ": " ^ show s a ^ ", want " ^ show s b ^ "\n") else ())
    end) ns
val dv = ref 0
val dw = ref 0w0
val dl = ref (0 : Int64.int)
val dx = ref (0w0 : Word64.word)
fun int (c, cs, fdiv, fmod, fquot, frem) =
  let val ns = ints c
      val () = dv := c
      fun go (name, f, g) = check (name, cs, Int.toString, Word.fromInt, ns) (f, g)
  in go ("div", fdiv, fn n => n div !dv); go ("mod", fmod, fn n => n mod !dv);
     go ("quot", fquot, fn n => Int.quot (n, !dv)); go ("rem", frem, fn n => Int.rem (n, !dv))
  end
fun word (c, cs, fdiv, fmod) =
  let val ns = words c
      val () = dw := c
      fun go (name, f, g) = check (name, cs, fn w => "0wx" ^ Word.toString w, fn w => w, ns) (f, g)
  in go ("wdiv", fdiv, fn n => n div !dw); go ("wmod", fmod, fn n => n mod !dw) end
fun int64 (c, cs, fdiv, fmod, fquot, frem) =
  let val ns = int64s c
      val () = dl := c
      fun go (name, f, g) = check (name, cs, Int64.toString, fn i => Word.fromLargeInt (Int64.toLarge i), ns) (f, g)
  in go ("div64", fdiv, fn n => n div !dl); go ("mod64", fmod, fn n => n mod !dl);
     go ("quot64", fquot, fn n => Int64.quot (n, !dl)); go ("rem64", frem, fn n => Int64.rem (n, !dl))
  end
fun word64 (c, cs, fdiv, fmod) =
  let val ns = word64s c
      val () = dx := c
      fun go (name, f, g) = check (name, cs, fn w => "0wx" ^ Word64.toString w, Word.fromLarge, ns) (f, g)
  in go ("wdiv64", fdiv, fn n => n div !dx); go ("wmod64", fmod, fn n => n mod !dx) end

(* the divisor through a join, a case, a loop and a handler: the code
   forgets what it knew where control arrives from elsewhere *)
val bsel = ref true
val ksel = ref 0
fun pick (b, n) = n div (if b then 3 else 5)
fun pickRef (b, n) = n div (if b then (dv := 3; !dv) else (dv := 5; !dv))
fun sel (k, n) = case k of 0 => n mod 3 | 1 => n mod ~7 | 2 => Int.quot (n, 1000003) | _ => n mod (k + 11)
fun selRef (k, n) = case k of 0 => (dv := 3; n mod !dv) | 1 => (dv := ~7; n mod !dv) | 2 => (dv := 1000003; Int.quot (n, !dv)) | _ => n mod (k + 11)
fun loop (i, acc, n) = if i = 0 then acc else loop (i - 1, acc + (n + i) div 7 + (n - i) mod 16777213, n)
fun loopRef (i, acc, n) = if i = 0 then acc else loopRef (i - 1, acc + (dv := 7; (n + i) div !dv) + (dv := 16777213; (n - i) mod !dv), n)
fun hd n = (n div 0 handle Div => n mod 10) + Int.quot (n, 9)
fun hdRef n = (n div (dv := 0; !dv) handle Div => (dv := 10; n mod !dv)) + (dv := 9; Int.quot (n, !dv))
(* and a register that held a literal, written again in the same run:
   7's register takes the sum, the divisor (Regs gives it the next value) *)
val msel = ref 3
val seven = ref 7
fun reuse (n, m) = let val a = n * 7 in n div (a + m) end
fun reuseRef (n, m) = let val a = n * !seven in n div (a + m) end
(* Pickle.hash's loop: four (h * k + x) mod p a byte *)
fun hash s =
  let val n = String.size s
      fun go (i, a, b, c, d) = if i = n then (a, b, c, d) else
        let val x = Char.ord (String.sub (s, i))
        in go (i + 1, (a * 31 + x) mod 16777213, (b * 37 + x) mod 16777199, (c * 41 + x) mod 16777183, (d * 43 + x) mod 16777153) end
  in go (0, 7, 11, 13, 17) end
fun hashRef s =
  let val n = String.size s
      fun go (i, a, b, c, d) = if i = n then (a, b, c, d) else
        let val x = Char.ord (String.sub (s, i))
        in go (i + 1, (dv := 16777213; (a * 31 + x) mod !dv), (dv := 16777199; (b * 37 + x) mod !dv),
               (dv := 16777183; (c * 41 + x) mod !dv), (dv := 16777153; (d * 43 + x) mod !dv)) end
  in go (0, 7, 11, 13, 17) end
fun flow () =
  List.app (fn n =>
    let fun eq (name, a, b) = (checks := !checks + 1; mix Word.fromInt a;
                               if a = b then () else (fails := !fails + 1; print ("FAIL " ^ name ^ " " ^ Int.toString n ^ ": " ^ show Int.toString a ^ ", want " ^ show Int.toString b ^ "\n")))
    in List.app (fn b => (bsel := b; eq ("pick", run (fn n => pick (!bsel, n)) n, run (fn n => pickRef (!bsel, n)) n))) [true, false];
       List.app (fn k => (ksel := k; eq ("sel", run (fn n => sel (!ksel, n)) n, run (fn n => selRef (!ksel, n)) n))) [0, 1, 2, 3];
       eq ("loop", run (fn n => loop (20, 0, n)) n, run (fn n => loopRef (20, 0, n)) n);
       eq ("hd", run hd n, run hdRef n);
       eq ("reuse", run (fn n => reuse (n, !msel)) n, run (fn n => reuseRef (n, !msel)) n)
    end) (ints 1000003)
val () = flow ()
val () =
  List.app (fn s => (checks := !checks + 1; if hash s = hashRef s then () else (fails := !fails + 1; print ("FAIL hash " ^ s ^ "\n"))))
    ["", "a", "hello, world", CharVector.tabulate (4000, fn i => Char.chr (i mod 256))]
(* each literal divisor of a table *)
val () = int (1, "1", fn n => n div 1, fn n => n mod 1, fn n => Int.quot (n, 1), fn n => Int.rem (n, 1))
val () = int (2, "2", fn n => n div 2, fn n => n mod 2, fn n => Int.quot (n, 2), fn n => Int.rem (n, 2))
val () = int (3, "3", fn n => n div 3, fn n => n mod 3, fn n => Int.quot (n, 3), fn n => Int.rem (n, 3))
val () = int (7, "7", fn n => n div 7, fn n => n mod 7, fn n => Int.quot (n, 7), fn n => Int.rem (n, 7))
val () = int (10, "10", fn n => n div 10, fn n => n mod 10, fn n => Int.quot (n, 10), fn n => Int.rem (n, 10))
val () = int (16, "16", fn n => n div 16, fn n => n mod 16, fn n => Int.quot (n, 16), fn n => Int.rem (n, 16))
val () = int (1000003, "1000003", fn n => n div 1000003, fn n => n mod 1000003, fn n => Int.quot (n, 1000003), fn n => Int.rem (n, 1000003))
val () = int (16777213, "16777213", fn n => n div 16777213, fn n => n mod 16777213, fn n => Int.quot (n, 16777213), fn n => Int.rem (n, 16777213))
val () = int (16777199, "16777199", fn n => n div 16777199, fn n => n mod 16777199, fn n => Int.quot (n, 16777199), fn n => Int.rem (n, 16777199))
val () = int (16777183, "16777183", fn n => n div 16777183, fn n => n mod 16777183, fn n => Int.quot (n, 16777183), fn n => Int.rem (n, 16777183))
val () = int (16777153, "16777153", fn n => n div 16777153, fn n => n mod 16777153, fn n => Int.quot (n, 16777153), fn n => Int.rem (n, 16777153))
val () = int (2147483647, "2147483647", fn n => n div 2147483647, fn n => n mod 2147483647, fn n => Int.quot (n, 2147483647), fn n => Int.rem (n, 2147483647))
val () = int (2147483648, "2147483648", fn n => n div 2147483648, fn n => n mod 2147483648, fn n => Int.quot (n, 2147483648), fn n => Int.rem (n, 2147483648))
val () = int (2147483649, "2147483649", fn n => n div 2147483649, fn n => n mod 2147483649, fn n => Int.quot (n, 2147483649), fn n => Int.rem (n, 2147483649))
val () = int (4294967291, "4294967291", fn n => n div 4294967291, fn n => n mod 4294967291, fn n => Int.quot (n, 4294967291), fn n => Int.rem (n, 4294967291))
val () = int (2305843009213693951, "2305843009213693951", fn n => n div 2305843009213693951, fn n => n mod 2305843009213693951, fn n => Int.quot (n, 2305843009213693951), fn n => Int.rem (n, 2305843009213693951))
val () = int (2305843009213693952, "2305843009213693952", fn n => n div 2305843009213693952, fn n => n mod 2305843009213693952, fn n => Int.quot (n, 2305843009213693952), fn n => Int.rem (n, 2305843009213693952))
val () = int (2305843009213693953, "2305843009213693953", fn n => n div 2305843009213693953, fn n => n mod 2305843009213693953, fn n => Int.quot (n, 2305843009213693953), fn n => Int.rem (n, 2305843009213693953))
val () = int (4611686018427387903, "4611686018427387903", fn n => n div 4611686018427387903, fn n => n mod 4611686018427387903, fn n => Int.quot (n, 4611686018427387903), fn n => Int.rem (n, 4611686018427387903))
val () = int (1152921504606846976, "1152921504606846976", fn n => n div 1152921504606846976, fn n => n mod 1152921504606846976, fn n => Int.quot (n, 1152921504606846976), fn n => Int.rem (n, 1152921504606846976))
val () = int (~2, "~2", fn n => n div ~2, fn n => n mod ~2, fn n => Int.quot (n, ~2), fn n => Int.rem (n, ~2))
val () = int (~3, "~3", fn n => n div ~3, fn n => n mod ~3, fn n => Int.quot (n, ~3), fn n => Int.rem (n, ~3))
val () = int (~7, "~7", fn n => n div ~7, fn n => n mod ~7, fn n => Int.quot (n, ~7), fn n => Int.rem (n, ~7))
val () = int (~16, "~16", fn n => n div ~16, fn n => n mod ~16, fn n => Int.quot (n, ~16), fn n => Int.rem (n, ~16))
val () = int (~1000003, "~1000003", fn n => n div ~1000003, fn n => n mod ~1000003, fn n => Int.quot (n, ~1000003), fn n => Int.rem (n, ~1000003))
val () = int (~16777213, "~16777213", fn n => n div ~16777213, fn n => n mod ~16777213, fn n => Int.quot (n, ~16777213), fn n => Int.rem (n, ~16777213))
val () = int (~2147483648, "~2147483648", fn n => n div ~2147483648, fn n => n mod ~2147483648, fn n => Int.quot (n, ~2147483648), fn n => Int.rem (n, ~2147483648))
val () = int (~2305843009213693951, "~2305843009213693951", fn n => n div ~2305843009213693951, fn n => n mod ~2305843009213693951, fn n => Int.quot (n, ~2305843009213693951), fn n => Int.rem (n, ~2305843009213693951))
val () = int (~4611686018427387904, "~4611686018427387904", fn n => n div ~4611686018427387904, fn n => n mod ~4611686018427387904, fn n => Int.quot (n, ~4611686018427387904), fn n => Int.rem (n, ~4611686018427387904))
val () = int (~4611686018427387903, "~4611686018427387903", fn n => n div ~4611686018427387903, fn n => n mod ~4611686018427387903, fn n => Int.quot (n, ~4611686018427387903), fn n => Int.rem (n, ~4611686018427387903))
val () = int (~1152921504606846976, "~1152921504606846976", fn n => n div ~1152921504606846976, fn n => n mod ~1152921504606846976, fn n => Int.quot (n, ~1152921504606846976), fn n => Int.rem (n, ~1152921504606846976))
val () = int (0, "0", fn n => n div 0, fn n => n mod 0, fn n => Int.quot (n, 0), fn n => Int.rem (n, 0))
val () = int (~1, "~1", fn n => n div ~1, fn n => n mod ~1, fn n => Int.quot (n, ~1), fn n => Int.rem (n, ~1))
val () = int (5, "5", fn n => n div 5, fn n => n mod 5, fn n => Int.quot (n, 5), fn n => Int.rem (n, 5))
val () = int (6, "6", fn n => n div 6, fn n => n mod 6, fn n => Int.quot (n, 6), fn n => Int.rem (n, 6))
val () = int (9, "9", fn n => n div 9, fn n => n mod 9, fn n => Int.quot (n, 9), fn n => Int.rem (n, 9))
val () = int (12, "12", fn n => n div 12, fn n => n mod 12, fn n => Int.quot (n, 12), fn n => Int.rem (n, 12))
val () = int (25, "25", fn n => n div 25, fn n => n mod 25, fn n => Int.quot (n, 25), fn n => Int.rem (n, 25))
val () = int (641, "641", fn n => n div 641, fn n => n mod 641, fn n => Int.quot (n, 641), fn n => Int.rem (n, 641))
val () = int (65536, "65536", fn n => n div 65536, fn n => n mod 65536, fn n => Int.quot (n, 65536), fn n => Int.rem (n, 65536))
val () = int (65537, "65537", fn n => n div 65537, fn n => n mod 65537, fn n => Int.quot (n, 65537), fn n => Int.rem (n, 65537))
val () = word (0w1, "0w1", fn n => n div 0w1, fn n => n mod 0w1)
val () = word (0w2, "0w2", fn n => n div 0w2, fn n => n mod 0w2)
val () = word (0w3, "0w3", fn n => n div 0w3, fn n => n mod 0w3)
val () = word (0w7, "0w7", fn n => n div 0w7, fn n => n mod 0w7)
val () = word (0w10, "0w10", fn n => n div 0w10, fn n => n mod 0w10)
val () = word (0w16, "0w16", fn n => n div 0w16, fn n => n mod 0w16)
val () = word (0w1000003, "0w1000003", fn n => n div 0w1000003, fn n => n mod 0w1000003)
val () = word (0w16777213, "0w16777213", fn n => n div 0w16777213, fn n => n mod 0w16777213)
val () = word (0w16777153, "0w16777153", fn n => n div 0w16777153, fn n => n mod 0w16777153)
val () = word (0w2147483647, "0w2147483647", fn n => n div 0w2147483647, fn n => n mod 0w2147483647)
val () = word (0w2147483648, "0w2147483648", fn n => n div 0w2147483648, fn n => n mod 0w2147483648)
val () = word (0w4294967291, "0w4294967291", fn n => n div 0w4294967291, fn n => n mod 0w4294967291)
val () = word (0w4294967296, "0w4294967296", fn n => n div 0w4294967296, fn n => n mod 0w4294967296)
val () = word (0w2305843009213693951, "0w2305843009213693951", fn n => n div 0w2305843009213693951, fn n => n mod 0w2305843009213693951)
val () = word (0w4611686018427387904, "0w4611686018427387904", fn n => n div 0w4611686018427387904, fn n => n mod 0w4611686018427387904)
val () = word (0w4611686018427387905, "0w4611686018427387905", fn n => n div 0w4611686018427387905, fn n => n mod 0w4611686018427387905)
val () = word (0wx7FFFFFFFFFFFFFFF, "0wx7FFFFFFFFFFFFFFF", fn n => n div 0wx7FFFFFFFFFFFFFFF, fn n => n mod 0wx7FFFFFFFFFFFFFFF)
val () = word (0wx7FFFFFFFFFFFFFFE, "0wx7FFFFFFFFFFFFFFE", fn n => n div 0wx7FFFFFFFFFFFFFFE, fn n => n mod 0wx7FFFFFFFFFFFFFFE)
val () = word (0wx5555555555555555, "0wx5555555555555555", fn n => n div 0wx5555555555555555, fn n => n mod 0wx5555555555555555)
val () = word (0w0, "0w0", fn n => n div 0w0, fn n => n mod 0w0)
val () = word (0w5, "0w5", fn n => n div 0w5, fn n => n mod 0w5)
val () = word (0w6, "0w6", fn n => n div 0w6, fn n => n mod 0w6)
val () = word (0w641, "0w641", fn n => n div 0w641, fn n => n mod 0w641)
val () = word (0w65537, "0w65537", fn n => n div 0w65537, fn n => n mod 0w65537)
val () = int64 (1, "1", fn n => n div 1, fn n => n mod 1, fn n => Int64.quot (n, 1), fn n => Int64.rem (n, 1))
val () = int64 (2, "2", fn n => n div 2, fn n => n mod 2, fn n => Int64.quot (n, 2), fn n => Int64.rem (n, 2))
val () = int64 (3, "3", fn n => n div 3, fn n => n mod 3, fn n => Int64.quot (n, 3), fn n => Int64.rem (n, 3))
val () = int64 (7, "7", fn n => n div 7, fn n => n mod 7, fn n => Int64.quot (n, 7), fn n => Int64.rem (n, 7))
val () = int64 (16777213, "16777213", fn n => n div 16777213, fn n => n mod 16777213, fn n => Int64.quot (n, 16777213), fn n => Int64.rem (n, 16777213))
val () = int64 (4611686018427387903, "4611686018427387903", fn n => n div 4611686018427387903, fn n => n mod 4611686018427387903, fn n => Int64.quot (n, 4611686018427387903), fn n => Int64.rem (n, 4611686018427387903))
val () = int64 (4611686018427387904, "4611686018427387904", fn n => n div 4611686018427387904, fn n => n mod 4611686018427387904, fn n => Int64.quot (n, 4611686018427387904), fn n => Int64.rem (n, 4611686018427387904))
val () = int64 (4611686018427387905, "4611686018427387905", fn n => n div 4611686018427387905, fn n => n mod 4611686018427387905, fn n => Int64.quot (n, 4611686018427387905), fn n => Int64.rem (n, 4611686018427387905))
val () = int64 (9223372036854775807, "9223372036854775807", fn n => n div 9223372036854775807, fn n => n mod 9223372036854775807, fn n => Int64.quot (n, 9223372036854775807), fn n => Int64.rem (n, 9223372036854775807))
val () = int64 (~3, "~3", fn n => n div ~3, fn n => n mod ~3, fn n => Int64.quot (n, ~3), fn n => Int64.rem (n, ~3))
val () = int64 (~7, "~7", fn n => n div ~7, fn n => n mod ~7, fn n => Int64.quot (n, ~7), fn n => Int64.rem (n, ~7))
val () = int64 (~4611686018427387904, "~4611686018427387904", fn n => n div ~4611686018427387904, fn n => n mod ~4611686018427387904, fn n => Int64.quot (n, ~4611686018427387904), fn n => Int64.rem (n, ~4611686018427387904))
val () = int64 (~4611686018427387905, "~4611686018427387905", fn n => n div ~4611686018427387905, fn n => n mod ~4611686018427387905, fn n => Int64.quot (n, ~4611686018427387905), fn n => Int64.rem (n, ~4611686018427387905))
val () = int64 (~9223372036854775807, "~9223372036854775807", fn n => n div ~9223372036854775807, fn n => n mod ~9223372036854775807, fn n => Int64.quot (n, ~9223372036854775807), fn n => Int64.rem (n, ~9223372036854775807))
val () = int64 (~9223372036854775808, "~9223372036854775808", fn n => n div ~9223372036854775808, fn n => n mod ~9223372036854775808, fn n => Int64.quot (n, ~9223372036854775808), fn n => Int64.rem (n, ~9223372036854775808))
val () = int64 (0, "0", fn n => n div 0, fn n => n mod 0, fn n => Int64.quot (n, 0), fn n => Int64.rem (n, 0))
val () = int64 (~1, "~1", fn n => n div ~1, fn n => n mod ~1, fn n => Int64.quot (n, ~1), fn n => Int64.rem (n, ~1))
val () = int64 (65536, "65536", fn n => n div 65536, fn n => n mod 65536, fn n => Int64.quot (n, 65536), fn n => Int64.rem (n, 65536))
val () = int64 (1000003, "1000003", fn n => n div 1000003, fn n => n mod 1000003, fn n => Int64.quot (n, 1000003), fn n => Int64.rem (n, 1000003))
val () = word64 (0w1, "0w1", fn n => n div 0w1, fn n => n mod 0w1)
val () = word64 (0w2, "0w2", fn n => n div 0w2, fn n => n mod 0w2)
val () = word64 (0w3, "0w3", fn n => n div 0w3, fn n => n mod 0w3)
val () = word64 (0w7, "0w7", fn n => n div 0w7, fn n => n mod 0w7)
val () = word64 (0w16777213, "0w16777213", fn n => n div 0w16777213, fn n => n mod 0w16777213)
val () = word64 (0wx7FFFFFFFFFFFFFFF, "0wx7FFFFFFFFFFFFFFF", fn n => n div 0wx7FFFFFFFFFFFFFFF, fn n => n mod 0wx7FFFFFFFFFFFFFFF)
val () = word64 (0wx8000000000000000, "0wx8000000000000000", fn n => n div 0wx8000000000000000, fn n => n mod 0wx8000000000000000)
val () = word64 (0wx8000000000000001, "0wx8000000000000001", fn n => n div 0wx8000000000000001, fn n => n mod 0wx8000000000000001)
val () = word64 (0wxFFFFFFFFFFFFFFFF, "0wxFFFFFFFFFFFFFFFF", fn n => n div 0wxFFFFFFFFFFFFFFFF, fn n => n mod 0wxFFFFFFFFFFFFFFFF)
val () = word64 (0wxFFFFFFFFFFFFFFFE, "0wxFFFFFFFFFFFFFFFE", fn n => n div 0wxFFFFFFFFFFFFFFFE, fn n => n mod 0wxFFFFFFFFFFFFFFFE)
val () = word64 (0wx5555555555555555, "0wx5555555555555555", fn n => n div 0wx5555555555555555, fn n => n mod 0wx5555555555555555)
val () = word64 (0w0, "0w0", fn n => n div 0w0, fn n => n mod 0w0)
val () = word64 (0w641, "0w641", fn n => n div 0w641, fn n => n mod 0w641)
val () = word64 (0w65537, "0w65537", fn n => n div 0w65537, fn n => n mod 0w65537)
val () = print (Int.toString (!checks) ^ " checks, " ^ Int.toString (!fails) ^ " failures, checksum 0wx" ^ Word.toString (!sum) ^ "\n")
val () = if !fails = 0 then () else OS.Process.exit OS.Process.failure
