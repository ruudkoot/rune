(* Generators over the implicit tree of PropertySource (docs/plans/quickcheck.md,
   D3 and the generator principles). A node stores its value in an encoding
   in which 0 is the simplest: an offset from the simplest value where a
   range is on one side of it, zigzag where it spans both. The bias of a
   generator is in its sampler, which picks the value; the shrinker lowers
   the stored word, and the decoding clamps whatever it finds into range, so
   that every word is a value of every generator. *)

(* Implements: GEN *)
structure Gen :> GEN =
struct
  structure S = PropertySource

  type 'a gen = S.source * S.position -> 'a

  fun draw (g : 'a gen) (s, a) = g (s, a)

  fun sample (g : 'a gen) (seed : Word64.word) (size : int) : 'a = g (S.new (seed, size, [], []), S.root)

  (* ---- combinators ---- *)

  fun return x : 'a gen = fn _ => x
  fun map f (g : 'a gen) : 'b gen = fn (s, a) => f (g (s, a))
  fun pair (g : 'a gen, h : 'b gen) : ('a * 'b) gen = fn (s, a) => (g (s, S.child (a, 1)), h (s, S.child (a, 2)))
  fun map2 f (g, h) = map f (pair (g, h))
  fun triple (g : 'a gen, h : 'b gen, k : 'c gen) : ('a * 'b * 'c) gen =
    fn (s, a) => (g (s, S.child (a, 1)), h (s, S.child (a, 2)), k (s, S.child (a, 3)))
  fun bind (g : 'a gen) (f : 'a -> 'b gen) : 'b gen =
    fn (s, a) => let val x = g (s, S.child (a, 1)) in f x (s, S.child (a, 2)) end
  fun sized (f : int -> 'a gen) : 'a gen = fn (s, a) => f (S.size s) (s, a)
  fun resize (n : int) (g : 'a gen) : 'a gen = fn (s, a) => g (S.resized (s, n), a)
  fun fix (f : 'a gen -> 'a gen) : 'a gen = let fun g x = f g x in g end

  (* ---- words and choices ---- *)

  (* a generator of Random for the rest of a node's sampling *)
  fun uniformBelow (n : Word64.word) (r : Word64.word) : Word64.word = #1 (Random.below n (Random.fromSeed r))

  (* the node at a, of kind k, whose word is below n: the choice among n
     things, 0 the simplest, the sample uniform *)
  fun choice (n : int) (s, a) : int =
    let val w = S.read (s, a, S.ChoiceNode, uniformBelow (Word64.fromInt n))
    in Int.min (Word64.toInt (Word64.min (w, Word64.fromInt (n - 1))), n - 1) end

  (* the index that weights ws choose for a uniform w below their sum *)
  fun weighted (ws : int list, w : int) : int =
    let
      fun go (_, [], _) = 0
        | go (i, x :: rest, acc) = if w < acc + x then i else go (i + 1, rest, acc + x)
    in go (0, ws, 0) end

  fun oneOf (gs : 'a gen list) : 'a gen =
    if List.null gs then raise Empty
    else
      let val v = Vector.fromList gs
      in fn (s, a) => Vector.sub (v, choice (Vector.length v) (s, S.child (a, 0))) (s, S.child (a, 1)) end

  fun frequency (ws : (int * 'a gen) list) : 'a gen =
    let
      val ws = List.filter (fn (w, _) => w > 0) ws
      val total = List.foldl (fn ((w, _), t) => w + t) 0 ws
      val v = Vector.fromList ws
    in
      if total = 0 then raise Empty
      else
        fn (s, a) =>
          let
            (* the stored word is the index, 0 the first; the sample is by weight *)
            val w = S.read (s, S.child (a, 0), S.ChoiceNode,
                            fn r => Word64.fromInt (weighted (List.map #1 ws, Word64.toInt (uniformBelow (Word64.fromInt total) r))))
            val i = Int.min (Word64.toInt (Word64.min (w, Word64.fromInt (Vector.length v - 1))), Vector.length v - 1)
          in
            #2 (Vector.sub (v, i)) (s, S.child (a, 1))
          end
    end

  fun elements (v : 'a vector) : 'a gen =
    if Vector.length v = 0 then raise Empty
    else fn (s, a) => Vector.sub (v, choice (Vector.length v) (s, a))

  exception Discarded

  fun filter p (g : 'a gen) : 'a gen =
    fn (s, a) =>
      let
        fun try 100 = raise Discarded
          | try i = let val x = g (s, S.child (a, i)) in if p x then x else try (i + 1) end
      in try 0 end

  (* ---- integers ---- *)

  fun zig (v : Word64.word) : Word64.word = Word64.xorb (Word64.<< (v, 0w1), Word64.~>> (v, 0w63))
  fun unzig (z : Word64.word) : Word64.word = Word64.xorb (Word64.>> (z, 0w1), Word64.~ (Word64.andb (z, 0w1)))

  fun clamp (lo, hi) v = if v < lo then lo else if v > hi then hi else v

  (* the edges of [lo, hi]: 0, 1, ~1, the bounds and their neighbours, and
     every power of two in range with its neighbours *)
  fun edges (lo : int, hi : int) : int list =
    let
      fun pows (p, acc) =
        let
          val acc = p :: p - 1 :: p + 1 :: acc
          val acc = if ~p >= lo then ~p :: ~p - 1 :: ~p + 1 :: acc else acc
        in
          (if p <= hi div 2 orelse ~p >= lo div 2 then pows (p * 2, acc) else acc) handle Overflow => acc
        end
      val candidates = [0, 1, ~1, lo, hi] @ ((lo + 1) :: [] handle Overflow => []) @ ((hi - 1) :: [] handle Overflow => [])
                       @ pows (2, [])
    in
      List.filter (fn v => lo <= v andalso v <= hi) candidates
    end
    handle Overflow => [0, lo, hi]

  (* uniform in [lo, hi] from the random word r *)
  fun uniformIn (lo : int, hi : int) (r : Word64.word) : int =
    let val span = Word64.+ (Word64.- (Word64.fromInt hi, Word64.fromInt lo), 0w1)
    in Word64.toIntX (Word64.+ (Word64.fromInt lo, if span = 0w0 then r else uniformBelow span r)) end

  fun intRange (lo : int, hi : int) : int gen =
    if hi < lo then raise Domain
    else
      let
        val es = Vector.fromList (edges (lo, hi))
        val target = clamp (lo, hi) 0
        (* offsets from the target in Word64, where they are exact whatever
           the width of int *)
        val (t, l, h) = (Word64.fromInt target, Word64.fromInt lo, Word64.fromInt hi)
        fun encode (v : int) : Word64.word =
          if lo >= 0 then Word64.- (Word64.fromInt v, t)
          else if hi <= 0 then Word64.- (t, Word64.fromInt v)
          else zig (Word64.- (Word64.fromInt v, t))
        fun decode (w : Word64.word) : int =
          (if lo >= 0 then Word64.toIntX (Word64.+ (t, Word64.min (w, Word64.- (h, t))))
           else if hi <= 0 then Word64.toIntX (Word64.- (t, Word64.min (w, Word64.- (t, l))))
           else clamp (lo, hi) (Word64.toIntX (Word64.+ (unzig w, t))))
          handle Overflow => target
        fun sampler size r =
          let
            val g = Random.fromSeed r
            val (family, g) = Random.below 0w3 g
            val (x, _) = Random.word64 g
          in
            encode (case family of
                      0w0 => uniformIn (clamp (lo, hi) (~size), clamp (lo, hi) size) x
                    | 0w1 => Vector.sub (es, Word64.toInt (uniformBelow (Word64.fromInt (Vector.length es)) x))
                    | _ => uniformIn (lo, hi) x)
          end
      in
        fn (s, a) => decode (S.read (s, a, S.IntNode, sampler (S.size s)))
      end

  val int : int gen =
    case (Int.minInt, Int.maxInt) of
      (SOME lo, SOME hi) => intRange (lo, hi)
    | _ => intRange (Int.fromLarge (~ (IntInf.pow (2, 63))), Int.fromLarge (IntInf.pow (2, 63) - 1))

  (* ---- words: the stored word is the value, 0 the simplest ---- *)

  (* words of `bits` bits, as 64-bit words *)
  fun wordsOf (bits : int) : Word64.word gen =
    let
      val max = if bits >= 64 then Word64.notb 0w0 else Word64.- (Word64.<< (0w1, Word.fromInt bits), 0w1)
      fun pows (k, acc) =
        if k >= bits then acc
        else
          let val p = Word64.<< (0w1, Word.fromInt k)
          in pows (k + 1, p :: Word64.- (p, 0w1) :: Word64.+ (p, 0w1) :: acc) end
      val es = Vector.fromList (List.filter (fn w => w <= max) ([0w0, 0w1, max, Word64.- (max, 0w1)] @ pows (1, [])))
      fun sampler size r =
        let
          val g = Random.fromSeed r
          val (family, g) = Random.below 0w3 g
          val (x, _) = Random.word64 g
        in
          case family of
            0w0 => uniformBelow (Word64.+ (Word64.min (Word64.fromInt (Int.max (size, 0)), max), 0w1)) x
          | 0w1 => Vector.sub (es, Word64.toInt (uniformBelow (Word64.fromInt (Vector.length es)) x))
          | _ => Word64.andb (x, max)
        end
    in
      fn (s, a) => Word64.min (S.read (s, a, S.WordNode, sampler (S.size s)), max)
    end

  val word64 : Word64.word gen = wordsOf 64
  val word : word gen = map (fn w => Word.fromLarge (Word64.toLarge w)) (wordsOf Word.wordSize)

  (* ---- characters: the stored word is the code ---- *)

  val letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  val spaces = " \t\n\r\011\012\000\127"
  val syntax = "~-+\\\"'.eEx0w#()[],;:_^"
  fun pick (text : string) (r : Word64.word) : Word64.word =
    Word64.fromInt (Char.ord (String.sub (text, Word64.toInt (uniformBelow (Word64.fromInt (String.size text)) r))))

  val char : char gen =
    fn (s, a) =>
      let
        fun sampler r =
          let
            val g = Random.fromSeed r
            val (family, g) = Random.below 0w6 g
            val (x, _) = Random.word64 g
          in
            case family of
              0w3 => pick letters x
            | 0w4 => pick spaces x
            | 0w5 => pick syntax x
            | _ => uniformBelow 0w256 x
          end
      in
        Char.chr (Word64.toInt (Word64.min (S.read (s, a, S.CharNode, sampler), 0w255)))
      end

  (* ---- reals: the stored word is the bits, 0 the simplest (0.0) ---- *)

  val bitsOf = S.bitsOf
  val realOf = S.realOf

  val specials : real vector =
    Vector.fromList [0.0, ~0.0, Real.posInf, Real.negInf, 0.0 / 0.0, Real.minPos,
                     Real.nextAfter (Real.minNormalPos, 0.0), Real.minNormalPos, Real.maxFinite,
                     1.0, ~1.0, 0.5, 9007199254740992.0, Real.nextAfter (9007199254740992.0, Real.posInf)]

  val real : real gen =
    fn (s, a) =>
      let
        val size = S.size s
        fun sampler r =
          let
            val g = Random.fromSeed r
            val (family, g) = Random.below 0w3 g
            val (x, _) = Random.word64 g
          in
            case family of
              0w0 => bitsOf (Vector.sub (specials, Word64.toInt (uniformBelow (Word64.fromInt (Vector.length specials)) x)))
            | 0w1 => bitsOf (real (uniformIn (~2 * size, 2 * size) x) / 2.0)
            | _ => x
          end
      in
        realOf (S.read (s, a, S.RealNode, sampler))
      end

  (* ---- the rest of the Basis's simple types ---- *)

  val bool : bool gen = fn (s, a) => S.read (s, a, S.BoolNode, fn r => Word64.andb (r, 0w1)) <> 0w0
  val unit : unit gen = fn _ => ()
  val order : order gen = map (fn 0 => LESS | 1 => EQUAL | _ => GREATER) (fn (s, a) => choice 3 (s, a))

  fun option (g : 'a gen) : 'a option gen =
    fn (s, a) =>
      if S.read (s, S.child (a, 0), S.ChoiceNode, fn r => if uniformBelow 0w4 r = 0w0 then 0w0 else 0w1) = 0w0 then NONE
      else SOME (g (s, S.child (a, 1)))

  (* ---- collections: a length, and a mark and a part per element ---- *)

  fun lengthOf (s, a) : int =
    let
      val size = Int.max (S.size s, 0)
      fun sampler r =
        let val g = Random.fromSeed r val (family, g) = Random.below 0w8 g val (x, _) = Random.word64 g
        in
          case family of
            0w0 => 0w0
          | 0w1 => Word64.fromInt (Int.min (1, size))
          | _ => uniformBelow (Word64.fromInt (size + 1)) x
        end
    in
      Word64.toInt (Word64.min (S.read (s, a, S.LengthNode, sampler), 0w1000000))
    end

  fun list (g : 'a gen) : 'a list gen =
    fn (s, a) =>
      let
        val n = lengthOf (s, S.child (a, 0))
        val marks = S.child (a, 1)
        val parts = S.child (a, 2)
        val () = S.sequence (s, {length = #address (S.child (a, 0)), parts = #path parts, marks = SOME (#path marks)})
        fun elements i =
          if i >= n then []
          else if S.read (s, S.child (marks, i), S.MarkNode, fn _ => 0w1) = 0w0 then elements (i + 1)
          else g (s, S.child (parts, i)) :: elements (i + 1)
      in
        elements 0
      end

  fun listOf (n : int gen) (g : 'a gen) : 'a list gen =
    fn (s, a) =>
      let
        val len = n (s, S.child (a, 0))
        val parts = S.child (a, 2)
        val () = S.sequence (s, {length = #address (S.child (a, 0)), parts = #path parts, marks = NONE})
      in
        List.tabulate (Int.max (len, 0), fn i => g (s, S.child (parts, i)))
      end

  val string : string gen = map String.implode (list char)
  fun vector g = map Vector.fromList (list g)
  fun array g = map Array.fromList (list g)

  (* ---- functions: the result at x is the part at the observation of x ---- *)

  fun function (co : 'a -> Word64.word, g : 'b gen) : ('a -> 'b) gen =
    fn (s, a) => fn x => g (s, S.childAt (a, co x))

  exception Generated

  (* A function of one of the first `classes` of D5 (docs/plans/quickcheck.md):
     0 pure, 1 raising Generated at some arguments, 2 observing its effects,
     chosen by a node, the pure one the simplest. Every call is logged for the
     report, and an effect-observing one's for the comparison of outcomes. *)
  fun functionIn (classes : int) (co : 'a -> Word64.word, showArg : 'a -> string, showRes : 'b -> string,
                                  g : 'b gen) : ('a -> 'b) gen =
    fn (s, a) =>
      let
        val class = if classes <= 1 then 0 else choice classes (s, S.child (a, 0))
        val results = S.child (a, 1)
        val raising = S.child (a, 2)
      in
        fn x =>
          let
            val w = co x
            (* 0 is a raise, so that the simplest raising function raises
               everywhere *)
            val raises =
              class = 1 andalso
              S.read (s, S.childAt (raising, w), S.ChoiceNode, fn r => if uniformBelow 0w4 r = 0w0 then 0w0 else 0w1) = 0w0
          in
            if raises then (S.call (s, a, showArg x ^ " => raise Generated"); raise Generated)
            else
              let
                val y = g (s, S.childAt (results, w))
                val text = showArg x ^ " => " ^ showRes y
              in
                S.call (s, a, text);
                if class = 2 then S.effect (s, text) else ();
                y
              end
          end
      end

  fun functionOf args = functionIn 3 args
  fun pureOf args = functionIn 1 args
end
