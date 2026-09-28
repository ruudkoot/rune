(* Properties: what must hold for every value a generator draws.

   A property is run on many cases, each drawn from its own source. It
   passes, fails with a class (`false`, or the exception a side raised) and a
   message, or is discarded because a condition does not hold. Two sides of
   a law are compared as outcomes: equal values, or the same exception
   (docs/plans/quickcheck.md, D6).

   Area: Property testing *)
signature PROP =
sig
  (* A property. *)
  type prop

  (* What a property does with one case. *)
  datatype verdict = Pass | Fail of {class : string, message : string} | Discard

  (* What a case gave: its verdict, the values drawn (shown, outermost
     first), and its labels, with the coverages it asks for. *)
  type result = {verdict : verdict, shown : string list, labels : string list,
                 covers : (string * real * bool) list}

  (* `run p (source, address)` runs `p` on the case of `source`: what the
     runner does. *)
  val run : prop -> PropertySource.source * Word64.word -> result

  (* `holds b` passes when `b` is `true`. *)
  val holds : bool -> prop

  (* `forAll a f` is the property `f x` for every `x` that `a` draws. An
     exception that `f x` raises fails the case, with the exception's name as
     its class. *)
  val forAll : 'a Arb.arb -> ('a -> prop) -> prop

  (* `forAllGen (g, show) f` is `forAll` with a generator and a printer. *)
  val forAllGen : 'a Gen.gen * ('a -> string) -> ('a -> prop) -> prop

  (* `equal a (l, r)` passes when `l ()` and `r ()` have the same outcome:
     values equal by `a`, or the same exception. *)
  val equal : 'a Arb.arb -> (unit -> 'a) * (unit -> 'a) -> prop

  (* `law (a, b) (l, r)` is the property that `l x` and `r x` have the same outcome.

     It is `forAll a` of `equal b (fn () => l x, fn () => r x)`, except that
     each side is given its own `x`, drawn anew from the same part of the
     tree: a side that changes an array or calls a function with effects does
     not change what the other side sees. *)
  val law : 'a Arb.arb * 'b Arb.arb -> ('a -> 'b) * ('a -> 'b) -> prop

  (* `==> (cond, p)` is `p ()` where `cond` holds, and discards the case where it does not.

     With `infix ==>` it is written `cond ==> p`. *)
  val ==> : bool * (unit -> prop) -> prop

  (* `label l p` is `p`, with the case counted under `l` in the report. *)
  val label : string -> prop -> prop

  (* `classify b l p` is `label l p` where `b` holds, and `p` otherwise. *)
  val classify : bool -> string -> prop -> prop

  (* `cover pct b l p` is `classify b l p`, and asks that at least `pct`
     percent of the cases be so; the report fails a run that falls short. *)
  val cover : real -> bool -> string -> prop -> prop
end
