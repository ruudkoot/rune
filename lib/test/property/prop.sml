(* Properties over the implicit tree (docs/plans/quickcheck.md, D6). *)

(* Implements: PROP *)
structure Prop :> PROP =
struct
  structure S = PropertySource

  datatype verdict = Pass | Fail of {class : string, message : string} | Discard

  type result = {verdict : verdict, shown : string list, labels : string list,
                 covers : (string * real * bool) list}

  type prop = S.source * S.position -> result

  fun run (p : prop) (s, a) = p (s, a)

  fun plain v : result = {verdict = v, shown = [], labels = [], covers = []}

  fun holds (b : bool) : prop = fn _ => plain (if b then Pass else Fail {class = "false", message = ""})

  fun exceptional (e : exn) : verdict =
    case e of
      Gen.Discarded => Discard
    | _ => Fail {class = "exception " ^ exnName e, message = exnMessage e}

  fun forAllGen (g : 'a Gen.gen, show : 'a -> string) (f : 'a -> prop) : prop =
    fn (s, a) =>
      (let
         val x = Gen.draw g (s, S.child (a, 1))
         val shown = show x
         val r = f x (s, S.child (a, 2)) handle e => plain (exceptional e)
       in
         {verdict = #verdict r, shown = shown :: #shown r, labels = #labels r, covers = #covers r}
       end)
      handle Gen.Discarded => plain Discard

  fun forAll ({gen, show, ...} : 'a Arb.arb) (f : 'a -> prop) : prop = forAllGen (gen, show) f

  datatype 'a outcome = Value of 'a | Raised of string * string

  (* the outcome of a side, and the calls it made of effect-observing functions *)
  fun outcome (s : S.source) (f : unit -> 'a) : 'a outcome * string list =
    let
      val _ = S.takeEffects s
      val v = Value (f ()) handle e => Raised (exnName e, exnMessage e)
    in
      (v, S.takeEffects s)
    end

  fun compare (b : 'b Arb.arb) (l : 'b outcome, r : 'b outcome) : verdict =
    case (l, r) of
      (Value x, Value y) =>
        if Arb.equal b (x, y) then Pass
        else Fail {class = "differ", message = "left " ^ #show b x ^ ", right " ^ #show b y}
    | (Raised (n, _), Raised (m, _)) =>
        if n = m then Pass else Fail {class = "raised " ^ n ^ " and " ^ m, message = ""}
    | (Raised (n, msg), Value y) => Fail {class = "left raised " ^ n, message = msg ^ "; right " ^ #show b y}
    | (Value x, Raised (m, msg)) => Fail {class = "right raised " ^ m, message = "left " ^ #show b x ^ "; " ^ msg}

  (* the verdict on two outcomes with their effects *)
  fun judge (b : 'b Arb.arb) ((l, le) : 'b outcome * string list, (r, re) : 'b outcome * string list) : verdict =
    case compare b (l, r) of
      Pass =>
        if le = re then Pass
        else Fail {class = "effects differ",
                   message = "left calls " ^ String.concatWith ", " le ^ "; right calls " ^ String.concatWith ", " re}
    | v => v

  fun equal (b : 'b Arb.arb) (l : unit -> 'b, r : unit -> 'b) : prop =
    fn (s, _) => plain (judge b (outcome s l, outcome s r))

  fun law (a : 'a Arb.arb, b : 'b Arb.arb) (l : 'a -> 'b, r : 'a -> 'b) : prop =
    fn (s, addr) =>
      (let
         val here = S.child (addr, 1)
         (* each side has an x of its own, drawn from the same nodes *)
         val xl = Gen.draw (#gen a) (s, here)
         val xr = Gen.draw (#gen a) (s, here)
       in
         {verdict = judge b (outcome s (fn () => l xl), outcome s (fn () => r xr)),
          shown = [#show a xl], labels = [], covers = []}
       end)
      handle Gen.Discarded => plain Discard

  infix ==>
  fun (cond : bool) ==> (p : unit -> prop) : prop = if cond then (fn sa => p () sa) else fn _ => plain Discard

  fun label (l : string) (p : prop) : prop =
    fn sa => let val r = p sa in {verdict = #verdict r, shown = #shown r, labels = l :: #labels r, covers = #covers r} end

  fun classify (b : bool) (l : string) (p : prop) : prop = if b then label l p else p

  fun cover (pct : real) (b : bool) (l : string) (p : prop) : prop =
    fn sa =>
      let val r = classify b l p sa
      in {verdict = #verdict r, shown = #shown r, labels = #labels r, covers = (l, pct, b) :: #covers r} end
end
