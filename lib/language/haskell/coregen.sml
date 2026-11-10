(* The generator of Core programs (coregen_sig.sml): a fixed prelude, as
   Core text, and a function `f` drawn by type from a seed, with the input it
   is applied to. *)
structure CoreGen : CORE_GEN =
struct
  open Core

  (* the prelude every program has: lists, map, take, a bottom, and the
     printing of a list of ints, each forced, to a bound *)
  val prelude = String.concatWith "\n"
    ["(data List (a) (Nil) (Cons a (List a)))",
     "(val bottom (forall (a) a) (\\ (@a) (case (prim exn_error \"bottom\") e (_ (prim raise @a e)))))",
     "(val map (forall (a b) (-> (-> a b) (List a) (List b)))",
     "  (\\ (@a @b (f (-> a b)) (xs (List a)))",
     "    (case xs ys",
     "      ((Nil) (con Nil @b))",
     "      ((Cons y rest) (let (fy b (f y)) (let (fr (List b) (map @a @b f rest)) (con Cons @b fy fr)))))))",
     "(val take (forall (a) (-> !Int (List a) (List a)))",
     "  (\\ (@a (n !Int) (xs (List a)))",
     "    (case (prim int_le n 0) stop",
     "      ((True) (con Nil @a))",
     "      ((False) (case xs ys",
     "                 ((Nil) (con Nil @a))",
     "                 ((Cons y rest) (case (prim int_sub n 1) m",
     "                                  (_ (let (tr (List a) (take @a m rest)) (con Cons @a y tr))))))))))",
     "(val digits (-> !Int Str)",
     "  (\\ ((n !Int))",
     "    (case (prim int_lt n 10) small",
     "      ((True) (case (prim int_add n 48) c (_ (case (prim char_chr c) ch (_ (prim str_from_char ch))))))",
     "      ((False) (case (prim int_quot n 10) q",
     "                 (_ (case (prim int_rem n 10) r",
     "                      (_ (case (digits q) a (_ (case (digits r) b (_ (prim str_concat a b)))))))))))))",
     "(val showInt (-> !Int Str)",
     "  (\\ ((n !Int))",
     "    (case (prim int_lt n 0) neg",
     "      ((True) (case (prim int_neg n) m (_ (case (digits m) d (_ (prim str_concat \"-\" d))))))",
     "      ((False) (digits n)))))",
     "(val printList (-> !Int (List Int) World World)",
     "  (\\ ((k !Int) (xs (List Int)) (w World))",
     "    (case (prim int_le k 0) stop",
     "      ((True) (prim print_str \"\\n\" w))",
     "      ((False)",
     "        (case xs ys",
     "          ((Nil) (prim print_str \"\\n\" w))",
     "          ((Cons y rest)",
     "            (case y v",
     "              (_ (case (showInt v) s",
     "                   (_ (case (prim print_str s w) w1",
     "                        (_ (case (prim print_str \" \" w1) w2",
     "                             (_ (case (prim int_sub k 1) k1 (_ (printList k1 rest w2)))))))))))))))))"]

  (* ---- Drawing ---- *)

  (* a generator's state: the next number of Lehmer's generator, and the
     next fresh name *)
  type gen = {seed : IntInf.int ref, names : int ref}

  val modulus : IntInf.int = 2147483647
  (* a number from 0 to n - 1 *)
  fun below ({seed, ...} : gen) n =
    (seed := IntInf.mod (IntInf.* (!seed, 48271), modulus);
     IntInf.toInt (IntInf.mod (!seed, IntInf.fromInt n)))
  fun chance (g, n) = below g n = 0
  fun pick (g, xs) = List.nth (xs, below g (length xs))
  fun fresh ({names, ...} : gen) base = (names := !names + 1; base ^ Int.toString (!names))

  datatype gty = GInt | GList | GFun

  val int = TCon "Int"
  val list = TApp (TCon "List", int)
  val intFun = TFun (int, int)
  fun tyOf GInt = int | tyOf GList = list | tyOf GFun = intFun

  fun var x = Atom (Var x)
  fun lit n = Lit (LInt (IntInf.fromInt n))
  fun vars (env, t) = List.mapPartial (fn (x, u) => if u = t then SOME x else NONE) env
  fun bottom t = App (var "bottom", [TyArg t])

  (* an expression of type Int, at most d deep, in env *)
  fun genInt (g, env, d) : exp =
    let
      val xs = vars (env, GInt)
      val fs = vars (env, GFun)
      fun leaf () = if not (null xs) andalso chance (g, 2) then var (pick (g, xs)) else Atom (lit (below g 25 - 5))
    in
      if d <= 0 then leaf ()
      else
        case below g 8 of
          0 => leaf ()
        | 1 =>
            let val (a, b) = (fresh g "a", fresh g "b")
            in Case (genInt (g, env, d - 1), a,
                     [AltDefault (Case (genInt (g, env, d - 1), b,
                                        [AltDefault (Prim (pick (g, ["int_add", "int_sub", "int_mul"]), [],
                                                           [Var a, Var b]))]))])
            end
        | 2 => let val y = fresh g "y" in Let (y, int, genInt (g, env, d - 1), genInt (g, (y, GInt) :: env, d - 1)) end
        | 3 =>
            let val (l, h, t) = (fresh g "l", fresh g "h", fresh g "t")
            in Case (genList (g, env, d - 1), l,
                     [AltCon ("Nil", [], genInt (g, env, d - 1)),
                      AltCon ("Cons", [h, t], genInt (g, (h, GInt) :: (t, GList) :: env, d - 1))])
            end
        | 4 =>
            if null fs then leaf ()
            else let val a = fresh g "a" in Let (a, int, genInt (g, env, d - 1), App (var (pick (g, fs)), [ValArg (Var a)])) end
        | 5 => Case (if chance (g, 2) then genInt (g, env, d - 1) else genList (g, env, d - 1), "_",
                     [AltDefault (genInt (g, env, d - 1))])
        | 6 => if chance (g, 4) then bottom int else leaf ()
        | _ => leaf ()
    end

  (* an expression of type List Int, at most d deep, in env *)
  and genList (g, env, d) : exp =
    let
      val ls = vars (env, GList)
      fun leaf () = if not (null ls) andalso chance (g, 3) = false then var (pick (g, ls)) else Con ("Nil", [int], [])
    in
      if d <= 0 then leaf ()
      else
        case below g 9 of
          0 => leaf ()
        | 1 =>
            let val (h, t) = (fresh g "h", fresh g "t")
            in Let (h, int, genInt (g, env, d - 1),
                    Let (t, list, genList (g, env, d - 1), Con ("Cons", [int], [Var h, Var t])))
            end
        | 2 =>
            let val (f, x, l) = (fresh g "f", fresh g "x", fresh g "l")
            in Let (f, intFun, Lam ([ValBinder (x, int)], genInt (g, (x, GInt) :: env, d - 1)),
                    Let (l, list, genList (g, (f, GFun) :: env, d - 1),
                         App (var "map", [TyArg int, TyArg int, ValArg (Var f), ValArg (Var l)])))
            end
        | 3 =>
            let val l = fresh g "l"
            in Let (l, list, genList (g, env, d - 1), App (var "take", [TyArg int, ValArg (lit (below g 7)), ValArg (Var l)])) end
        | 4 =>
            let val (l, h, t) = (fresh g "l", fresh g "h", fresh g "t")
            in Case (genList (g, env, d - 1), l,
                     [AltCon ("Nil", [], genList (g, env, d - 1)),
                      AltCon ("Cons", [h, t], genList (g, (h, GInt) :: (t, GList) :: env, d - 1))])
            end
        | 5 =>
            let val xs = fresh g "xs"
            in LetRec ([(xs, list, Con ("Cons", [int], [lit (below g 10), Var xs]))], genList (g, (xs, GList) :: env, d - 1)) end
        | 6 => Case (genInt (g, env, d - 1), "_", [AltDefault (genList (g, env, d - 1))])
        | 7 => if chance (g, 4) then bottom list else leaf ()
        | _ => leaf ()
    end

  (* the input: up to five elements, each a literal or a bottom, then Nil
     or a bottom *)
  fun input g =
    let
      val n = below g 6
      fun go 0 = if chance (g, 4) then bottom list else Con ("Nil", [int], [])
        | go k =
            let val (h, t) = (fresh g "i", fresh g "r")
            in Let (h, int, if chance (g, 5) then bottom int else Atom (lit (below g 100)),
                    Let (t, list, go (k - 1), Con ("Cons", [int], [Var h, Var t])))
            end
    in go n end

  fun program seed =
    let
      val g = {seed = ref (IntInf.fromInt (1 + Int.abs seed mod 2147483646)), names = ref 0}
      val _ = below g 2
      (* a body that is more than a leaf, in a few draws *)
      fun leaf (Atom _) = true
        | leaf (Con (_, _, [])) = true
        | leaf _ = false
      fun draw k = let val b = genList (g, [("input", GList)], 6) in if leaf b andalso k > 0 then draw (k - 1) else b end
      val body = draw 8
      val f = Val ("f", TFun (list, list), Lam ([ValBinder ("input", list)], body))
      val main =
        Val ("main", TFun (TCon "World", TUTuple [TCon "World", int]),
             Lam ([ValBinder ("w", TCon "World")],
                  Let ("xs", list, input g,
                       Let ("ys", list, App (var "f", [ValArg (Var "xs")]),
                            Case (App (var "printList", [ValArg (lit 20), ValArg (Var "ys"), ValArg (Var "w")]), "w1",
                                  [AltDefault (UTuple [Var "w1", lit 0])])))))
    in CoreText.parse prelude @ [f, main] end
end
