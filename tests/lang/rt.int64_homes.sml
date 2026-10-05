(* Tier 2's homes (runtime/register/jit, compile.c): a machine register is
   the home of several of a function's registers, where no two of them are
   live together. Each function here keeps more numbers live than there
   are homes, across what clobbers them or reads them late: a call into C,
   a call of a known function and of a closure, a tail call that permutes
   its arguments, a return, a handler. The functions recur so that they
   stay functions; the numbers pass 63 bits so that one that went through
   a slot as a box and one that stayed in its home are told apart only by
   being right. *)

fun w2s (w : Word64.word) = Word64.toString w
fun i2s (i : int) = Int.toString i

(* eight words live around the loop, and temporaries between them *)
fun mix (0, a : Word64.word, b : Word64.word, c : Word64.word, d : Word64.word,
         e : Word64.word, f : Word64.word, g : Word64.word, h : Word64.word) =
      Word64.xorb (Word64.xorb (Word64.xorb (a, b), Word64.xorb (c, d)),
                   Word64.xorb (Word64.xorb (e, f), Word64.xorb (g, h)))
  | mix (n, a, b, c, d, e, f, g, h) =
      let
        val t1 = Word64.+ (Word64.* (a, 0wx9E3779B97F4A7C15), b)
        val t2 = Word64.xorb (c, Word64.>> (t1, 0w29))
        val t3 = Word64.+ (d, Word64.<< (t2, 0w7))
        val t4 = Word64.* (Word64.xorb (e, t3), 0wxBF58476D1CE4E5B9)
        val t5 = Word64.- (f, Word64.>> (t4, 0w31))
        val t6 = Word64.xorb (g, Word64.+ (t5, t1))
        val t7 = Word64.+ (h, Word64.* (t6, 0wx94D049BB133111EB))
      in mix (n - 1, t7, t1, t2, t3, t4, t5, t6, Word64.xorb (t7, a)) end

(* the same with a call into C in the middle of each round: the homes
   that C clobbers are loaded again, each with its own register's value *)
fun mixc (0, a : Word64.word, b : Word64.word, c : Word64.word, d : Word64.word, acc) = (a, b, c, d, acc)
  | mixc (n, a, b, c, d, acc) =
      let
        val t1 = Word64.+ (Word64.* (a, 0wx9E3779B97F4A7C15), b)
        val s1 = if n mod 7 = 0 then size (w2s t1) else 0
        val t2 = Word64.xorb (c, Word64.>> (t1, 0w29))
        val t3 = Word64.+ (d, Word64.<< (t2, 0w7))
        val s2 = if n mod 5 = 0 then size (i2s n) else 1
        val t4 = Word64.* (Word64.xorb (t1, t3), 0wxBF58476D1CE4E5B9)
      in mixc (n - 1, t4, t1, t2, t3, acc + s1 + s2) end

(* ints, chars and words together, more than the homes *)
fun ints (0, a, b, c, d, e, f, g, h, ch, acc) = (a + b + c + d + e + f + g + h + ord ch + acc)
  | ints (n, a, b, c, d, e, f, g, h, ch, acc) =
      let
        val p = a + b * 3
        val q = c - d
        val r = e * 2 + f
        val s = g - h + p
        val ch' = chr ((ord ch + q mod 7 + 7) mod 128)
        val t = (p + q + r + s) mod 1000003
      in ints (n - 1, t, p mod 1009, q mod 1013, r mod 1019, s mod 1021, a mod 1031, b + 1, c + 2, ch', acc + ord ch') end

(* a known function of many arguments, called and not in tail position:
   the arguments leave their homes for the callee's registers, the
   caller's come back after *)
fun many (a : Word64.word, b : Word64.word, c : int, d : int, e : Word64.word, f : int, g : Word64.word, h : int, k : int) : Word64.word =
  if k = 0 then Word64.xorb (Word64.xorb (a, b), Word64.xorb (e, g)) + Word64.fromInt (c + d + f + h)
  else
    let
      val x = many (b, a, d, c, g, h, e, f, k - 1)
      val y = Word64.+ (Word64.* (a, x), Word64.fromInt (c * f - d * h))
    in Word64.xorb (y, Word64.+ (b, Word64.xorb (e, g))) end

(* a tail call that turns its arguments around: each goes to another's
   register, and none through one that holds a later one *)
fun turn (0, a : Word64.word, b : Word64.word, c : int, d : int, e : Word64.word, f : int) =
      (Word64.xorb (a, Word64.xorb (b, e)), c * 1000000 + d * 1000 + f)
  | turn (n, a, b, c, d, e, f) = other (n - 1, e, a, f, c, b, d)
and other (n, a, b, c, d, e, f) =
      if n mod 3 = 0 then turn (n, Word64.+ (b, 0w1), Word64.* (a, 0w3), d, c + 1, Word64.xorb (e, a), f)
      else turn (n, b, e, d, f, a, c)

(* through closures: the argument may be in any home, the result comes
   back to any, and what is live across the call returns to its home *)
fun apply (f : Word64.word -> Word64.word, 0, x : Word64.word, y : Word64.word, z : Word64.word, i : int, j : int, k : int) =
      (Word64.xorb (x, Word64.xorb (y, z)), i + j + k)
  | apply (f, n, x, y, z, i, j, k) =
      let
        val x' = f (Word64.+ (x, y))
        val y' = f (Word64.xorb (y, z))
        val i' = i + Word64.toInt (Word64.andb (x', 0w255))
        val z' = Word64.+ (f z, Word64.fromInt (j * k))
      in apply (f, n - 1, z', x', y', j, k, i' mod 9973) end
fun tails (f : int * Word64.word -> Word64.word, n, w : Word64.word, a : int, b : int, c : int) : Word64.word =
  if n = 0 then Word64.+ (w, Word64.fromInt (a + b + c))
  else if n mod 4 = 0 then f (a * b + c, Word64.* (w, 0wx100000001B3))
  else tails (f, n - 1, Word64.xorb (Word64.* (w, 0wx100000001B3), Word64.fromInt n), b, c, a + 1)

(* a handler: what it needs is live in its homes wherever a raise may
   come from, and what the body made is not *)
exception Stop of int
fun guarded (0, a : Word64.word, b : Word64.word, c : int, d : int) = (a, b, c, d)
  | guarded (n, a, b, c, d) =
      let
        val (a', c') =
          (let
             val t = Word64.* (Word64.+ (a, b), 0wx9E3779B97F4A7C15)
             val u = c * 31 + d
           in if n mod 3 = 0 then raise Stop (u mod 1000) else (Word64.xorb (t, a), u mod 100003) end)
          handle Stop k => (Word64.+ (b, Word64.fromInt (k + d)), c + k)
      in guarded (n - 1, b, a', d + 1, c') end

(* reals and words in one loop, a real's home across a call into C *)
fun both (0, x : real, y : real, z : real, w : Word64.word, v : Word64.word, i : int) = (x, y, z, w, v, i)
  | both (n, x, y, z, w, v, i) =
      let
        val x' = x * 1.0000001 + y / 3.0
        val w' = Word64.+ (Word64.* (w, 0wx5851F42D4C957F2D), v)
        val y' = if n mod 11 = 0 then Math.sqrt (y * y + 1.0) else y - z * 0.5
        val v' = Word64.xorb (v, Word64.>> (w', 0w17))
        val z' = z + Real.fromInt (i mod 13) * 0.25
        val i' = i + Real.floor (x' - Real.realFloor x' + 0.5)
      in both (n - 1, y', z', x' - Real.realFloor x', v', w', i') end

(* fourteen words and thirty-two reals live at once, more than any machine
   has homes for: the ones without live in their slots, beside the ones
   with, and a call into C and an allocation come between *)
fun wide (0, w1 : Word64.word, w2 : Word64.word, w3 : Word64.word, w4 : Word64.word, w5 : Word64.word, w6 : Word64.word, w7 : Word64.word, w8 : Word64.word, w9 : Word64.word, w10 : Word64.word, w11 : Word64.word, w12 : Word64.word, w13 : Word64.word, w14 : Word64.word) =
      List.foldl Word64.xorb 0w0 [w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14]
  | wide (n, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14) =
      let
        val t = Word64.+ (Word64.* (w1, 0wx9E3779B97F4A7C15), w14)
        val u = Word64.xorb (w7, Word64.>> (t, 0w23))
        val s = if n mod 9 = 0 then size (w2s u) else 0
      in wide (n - 1, w2, w3, Word64.+ (w4, t), w5, w6, u, w8, Word64.xorb (w9, w1), w10, w11, Word64.+ (w12, Word64.fromInt s), w13, t, Word64.- (w1, u)) end

fun rwide (0, r1 : real, r2 : real, r3 : real, r4 : real, r5 : real, r6 : real, r7 : real, r8 : real, r9 : real, r10 : real, r11 : real, r12 : real, r13 : real, r14 : real, r15 : real, r16 : real, r17 : real, r18 : real, r19 : real, r20 : real, r21 : real, r22 : real, r23 : real, r24 : real, r25 : real, r26 : real, r27 : real, r28 : real, r29 : real, r30 : real, r31 : real, r32 : real) =
      r1 + r2 + r3 + r4 + r5 + r6 + r7 + r8 + r9 + r10 + r11 + r12 + r13 + r14 + r15 + r16 + r17 + r18 + r19 + r20 + r21 + r22 + r23 + r24 + r25 + r26 + r27 + r28 + r29 + r30 + r31 + r32
  | rwide (n, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20, r21, r22, r23, r24, r25, r26, r27, r28, r29, r30, r31, r32) =
      let
        val a = r1 * 0.5 + r32 * 0.25 + r16 * 0.125
        val b = if n mod 7 = 0 then Math.sin a else a - Real.realFloor a
        val c = if n mod 13 = 0 then #1 (List.foldl (fn (x, (s, k)) => (s + x, k + 1)) (b, 0) [r3, r30]) else r9 - b
      in rwide (n - 1, r2, r3, r4, r5, r6 + b, r7, r8, r9, r10, r11, r12, r13, r14 - c * 0.5, r15, r16, r17, r18, r19, r20, r21, r22 * 0.999 + a * 0.001, r23, r24, r25, r26, r27, r28, c, r30, r31, r32, a) end

val () = print (w2s (mix (1000, 0w1, 0w2, 0w3, 0w4, 0w5, 0w6, 0w7, 0w8)) ^ "\n")
val () = let val (a, b, c, d, acc) = mixc (1000, 0wxFFFFFFFFFFFFFFF1, 0w2, 0w3, 0wx8000000000000000, 0)
         in print (w2s a ^ " " ^ w2s b ^ " " ^ w2s c ^ " " ^ w2s d ^ " " ^ i2s acc ^ "\n") end
val () = print (i2s (ints (1000, 1, 2, 3, 4, 5, 6, 7, 8, #"a", 0)) ^ "\n")
val () = print (w2s (many (0wxFEDCBA9876543210, 0wx8000000000000001, 3, 4, 0wxFFFFFFFFFFFFFFFF, 5, 0wx0123456789ABCDEF, 6, 40)) ^ "\n")
val () = let val (w, i) = turn (1000, 0wxF000000000000001, 0w2, 3, 4, 0wx8000000000000005, 6)
         in print (w2s w ^ " " ^ i2s i ^ "\n") end
val () = let val k = Word64.fromInt (size (CommandLine.name ()) * 0 + 7)
             val (w, i) = apply (fn w => Word64.+ (Word64.* (w, 0wx9E3779B97F4A7C15), k), 500, 0wxFFFFFFFFFFFFFFFE, 0w2, 0wx8000000000000003, 4, 5, 6)
         in print (w2s w ^ " " ^ i2s i ^ "\n") end
val () = print (w2s (tails (fn (i, w) => Word64.xorb (w, Word64.fromInt i), 1001, 0wxCBF29CE484222325, 1, 2, 3)) ^ " "
                ^ w2s (tails (fn (i, w) => Word64.+ (w, Word64.fromInt (i * 2)), 3, 0wxFFFFFFFFFFFFFFFF, 7, 8, 9)) ^ "\n")
val () = let val (a, b, c, d) = guarded (1000, 0wxFFFFFFFFFFFFFFFF, 0wx8000000000000000, 1, 2)
         in print (w2s a ^ " " ^ w2s b ^ " " ^ i2s c ^ " " ^ i2s d ^ "\n") end
val () = let val (x, y, z, w, v, i) = both (1000, 0.5, 1.5, 2.5, 0wxFFFFFFFFFFFFFFFF, 0wx8000000000000001, 0)
         in print (Real.fmt (StringCvt.FIX (SOME 6)) x ^ " " ^ Real.fmt (StringCvt.FIX (SOME 6)) y ^ " " ^ Real.fmt (StringCvt.FIX (SOME 6)) z
                   ^ " " ^ w2s w ^ " " ^ w2s v ^ " " ^ i2s i ^ "\n") end
val () = print (w2s (wide (1000, 0wx8000000000000001, 0wx8123456789ABCDF0, 0wx82468ACF13579BDF, 0wx8369D0369D0369CE, 0wx848D159E26AF37BD, 0wx85B05B05B05B05AC, 0wx86D3A06D3A06D39B, 0wx87F6E5D4C3B2A18A, 0wx891A2B3C4D5E6F79, 0wx8A3D70A3D70A3D68, 0wx8B60B60B60B60B57, 0wx8C83FB72EA61D946, 0wx8DA740DA740DA735, 0wx8ECA8641FDB97524)) ^ "\n")
val () = print (Real.fmt (StringCvt.FIX (SOME 6)) (rwide (1000, 1.1, 2.2, 3.3, 4.4, 0.5, 1.6, 2.7, 3.8, 4.9, 0.10, 1.11, 2.12, 3.13, 4.14, 0.15, 1.16, 2.17, 3.18, 4.19, 0.20, 1.21, 2.22, 3.23, 4.24, 0.25, 1.26, 2.27, 3.28, 4.29, 0.30, 1.31, 2.32)) ^ "\n")
