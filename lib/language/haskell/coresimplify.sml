(* The Core simplifier's passes (coresimplify_sig.sml). *)
structure CoreSimplify : CORE_SIMPLIFY =
struct
  open Core
  structure B = CoreSimplifyBase
  structure S = CoreSimplifySimp

  datatype eta = Pedantic | Ghc

  type options = {spend : unit -> bool, whole : bool, eta : eta, cheap : bool}

  (* how many rounds a simplification runs at most, and how many rounds of
     copies a specialisation makes *)
  val maxRounds = 6
  val maxSpecRounds = 6

  fun setup (opts : options) = (B.spendRef := #spend opts; S.whole := #whole opts)

  fun total () = List.foldl (fn ((_, r), n) => n + !r) 0 (!B.counts)

  (* rounds of p until one makes no rewrite, or n have run *)
  fun rounds (p : program, n : int) : program =
    if n = 0 then p
    else
      let
        val start = total ()
        val p' = S.round p
      in if total () = start then p' else rounds (p', n - 1) end

  fun simplify (opts : options) (p : program) : program =
    (setup opts; rounds (B.distinct p, maxRounds))

  fun specialise (opts : options) (p : program) : program =
    let
      val () = setup opts
      fun go (p, n) =
        if n = 0 then p
        else
          let val (p', made) = CoreSimplifySpec.round p
          in if made = 0 then p' else go (rounds (p', maxRounds), n - 1) end
    in go (p, maxSpecRounds) end

  fun eta (opts : options) (p : program) : program =
    let
      val () = setup opts
      val mode = case #eta opts of Pedantic => CoreSimplifyEta.Pedantic | Ghc => CoreSimplifyEta.Ghc
    in rounds (CoreSimplifyEta.program (mode, p), 2) end

  fun simplify2 (opts : options) (p : program) : program = (setup opts; rounds (p, maxRounds))

  fun cheap (opts : options) (p : program) : program =
    if #cheap opts then (setup opts; CoreSimplifyCheap.program p) else p

  fun passes () =
    [("core-simplify", simplify), ("core-specialise", specialise), ("core-eta", eta), ("core-cheap", cheap),
     ("core-simplify-2", simplify2)]

  fun counts () = List.map (fn (w, r) => (w, !r)) (!B.counts)
  fun resetCounts () = B.counts := []

  (* ---- Unfoldings ---- *)

  (* the size of an unfolding a client may inline, and of an overloaded
     function it may specialise *)
  val unfoldingSize = 30
  val overloadedSize = 400

  fun unfoldings (p : program) : decl list =
    let
      val dt = B.datatypes p
      fun keep (x, t, e) =
        case e of
          Con _ => true
        | Lam _ =>
            B.sizeUpTo unfoldingSize e <= unfoldingSize
            orelse (isSome (CoreSimplifySpec.overloadedOf dt (t, e)) andalso B.sizeUpTo overloadedSize e <= overloadedSize)
        | _ => false
    in List.filter (fn Val (v as (x, _, _)) => x <> "main" andalso keep v | _ => false) p end
end
