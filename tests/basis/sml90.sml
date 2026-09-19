(* requires: SML90 *)
(* SML90, the initial basis of the 1990 Definition. The page of the
   specification is gone from https://smlfamily.github.io/Basis/; the checks
   follow the Definition of 1990 and MLton's SML90: the arithmetic exceptions
   are Overflow and Mod is Div (whether Quot is Overflow or Div is left out:
   SML/NJ has Div, MLton and Poly/ML Overflow). The files are made in the
   current directory, which the runner makes a new scratch directory. *)
structure TestSML90 =
struct
  val eqS = T.eq T.string
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqSL = T.eq (T.list T.string)
  val isOrd = fn SML90.Ord => true | _ => false
  val isIo = fn SML90.Io _ => true | _ => false

  (*<< exceptions *)
  fun sameAs (label, raiseIt, handler) =
    T.check (label, fn () => (raiseIt () ; false) handle e => handler e)
  val () = sameAs ("SML90.Abs/is-Overflow", fn () => raise SML90.Abs, T.isOverflow)
  val () = sameAs ("SML90.Prod/is-Overflow", fn () => raise SML90.Prod, T.isOverflow)
  val () = sameAs ("SML90.Neg/is-Overflow", fn () => raise SML90.Neg, T.isOverflow)
  val () = sameAs ("SML90.Sum/is-Overflow", fn () => raise Overflow, fn SML90.Sum => true | _ => false)
  val () = sameAs ("SML90.Diff/is-Overflow", fn () => raise SML90.Diff, T.isOverflow)
  val () = sameAs ("SML90.Floor/is-Overflow", fn () => raise SML90.Floor, T.isOverflow)
  val () = sameAs ("SML90.Exp/is-Overflow", fn () => raise SML90.Exp, T.isOverflow)
  val () = sameAs ("SML90.Mod/is-Div", fn () => raise SML90.Mod, T.isDiv)
  val () = sameAs ("SML90.Quot/handled", fn () => raise SML90.Quot, fn SML90.Quot => true | _ => false)
  val () = sameAs ("SML90.Sqrt/new", fn () => raise SML90.Sqrt,
                   fn Domain => false | Overflow => false | SML90.Sqrt => true | _ => false)
  val () = sameAs ("SML90.Ln/new", fn () => raise SML90.Ln,
                   fn Domain => false | SML90.Sqrt => false | SML90.Ln => true | _ => false)
  val () = sameAs ("SML90.Ord/new", fn () => raise SML90.Ord,
                   fn Subscript => false | Chr => false | SML90.Ord => true | _ => false)
  val () = sameAs ("SML90.Interrupt/new", fn () => raise SML90.Interrupt,
                   fn Overflow => false | Div => false | SML90.Interrupt => true | _ => false)
  val () = eqS ("SML90.Io/carries-a-string", "why",
                fn () => (raise SML90.Io "why") handle SML90.Io s => s)
  (*>> exceptions *)

  (*<< math *)
  val () = T.eqReal ("SML90.sqrt/4", 2.0, fn () => SML90.sqrt 4.0)
  val () = T.eqReal ("SML90.sqrt/zero", 0.0, fn () => SML90.sqrt 0.0)
  val () = T.raises ("SML90.sqrt/Sqrt-negative", fn SML90.Sqrt => true | _ => false, fn () => SML90.sqrt ~1.0)
  val () = T.eqReal ("SML90.exp/zero", 1.0, fn () => SML90.exp 0.0)
  val () = T.eqReal ("SML90.exp/underflow-is-zero", 0.0, fn () => SML90.exp ~1000.0)
  val () = T.raises ("SML90.exp/Exp-overflow", fn SML90.Exp => true | _ => false, fn () => SML90.exp 1000.0)
  val () = T.eqReal ("SML90.ln/one", 0.0, fn () => SML90.ln 1.0)
  val () = T.approx ("SML90.ln/e", 1.0, fn () => SML90.ln Math.e)
  val () = T.raises ("SML90.ln/Ln-zero", fn SML90.Ln => true | _ => false, fn () => SML90.ln 0.0)
  val () = T.raises ("SML90.ln/Ln-negative", fn SML90.Ln => true | _ => false, fn () => SML90.ln ~1.0)
  val () = T.eqReal ("SML90.sin/zero", 0.0, fn () => SML90.sin 0.0)
  val () = T.approx ("SML90.sin/half-pi", 1.0, fn () => SML90.sin (Math.pi / 2.0))
  val () = T.eqReal ("SML90.cos/zero", 1.0, fn () => SML90.cos 0.0)
  val () = T.approx ("SML90.cos/pi", ~1.0, fn () => SML90.cos Math.pi)
  val () = T.eqReal ("SML90.arctan/zero", 0.0, fn () => SML90.arctan 0.0)
  val () = T.approx ("SML90.arctan/one", Math.pi / 4.0, fn () => SML90.arctan 1.0)
  (*>> math *)

  (*<< strings *)
  val () = eqI ("SML90.ord/first-character", 97, fn () => SML90.ord "abc")
  val () = eqI ("SML90.ord/255", 255, fn () => SML90.ord "\255")
  val () = T.raises ("SML90.ord/Ord-empty", isOrd, fn () => SML90.ord "")
  val () = eqS ("SML90.chr/97", "a", fn () => SML90.chr 97)
  val () = eqS ("SML90.chr/zero", "\000", fn () => SML90.chr 0)
  val () = T.raises ("SML90.chr/Chr-256", T.isChr, fn () => SML90.chr 256)
  val () = T.raises ("SML90.chr/Chr-negative", T.isChr, fn () => SML90.chr ~1)
  val () = eqSL ("SML90.explode/letters", ["a", "b", "c"], fn () => SML90.explode "abc")
  val () = eqSL ("SML90.explode/empty", [], fn () => SML90.explode "")
  val () = eqS ("SML90.implode/strings", "abcd", fn () => SML90.implode ["ab", "", "c", "d"])
  val () = eqS ("SML90.implode/empty", "", fn () => SML90.implode [])
  (*>> strings *)

  (*<< streams *)
  val file = "sml90.txt"
  fun writeFile s = let val out = SML90.open_out file in SML90.output (out, s); SML90.close_out out end
  val () = eqS ("SML90.output/then-input", "hello\nworld",
                fn () => (writeFile "hello\nworld";
                          let val ins = SML90.open_in file
                          in SML90.input (ins, 100) before SML90.close_in ins end))
  val () = eqSL ("SML90.input/at-most-n", ["hel", "lo\nw", "orld", ""],
                 fn () => (writeFile "hello\nworld";
                           let val ins = SML90.open_in file
                               val a = SML90.input (ins, 3)
                               val b = SML90.input (ins, 4)
                               val c = SML90.input (ins, 10)
                               val d = SML90.input (ins, 10)
                           in SML90.close_in ins; [a, b, c, d] end))
  val () = eqS ("SML90.input/zero", "",
                fn () => (writeFile "abc";
                          let val ins = SML90.open_in file in SML90.input (ins, 0) before SML90.close_in ins end))
  val () = eqSL ("SML90.lookahead/does-not-consume", ["a", "a", "ab", "", ""],
                 fn () => (writeFile "ab";
                           let val ins = SML90.open_in file
                               val a = SML90.lookahead ins
                               val b = SML90.lookahead ins
                               val c = SML90.input (ins, 5)
                               val d = SML90.lookahead ins
                               val e = SML90.input (ins, 5)
                           in SML90.close_in ins; [a, b, c, d, e] end))
  val () = eqS ("SML90.lookahead/empty-file", "",
                fn () => (writeFile "";
                          let val ins = SML90.open_in file in SML90.lookahead ins before SML90.close_in ins end))
  val () = T.eq (T.list T.bool) ("SML90.end_of_stream/before-and-after", [false, false, true],
                fn () => (writeFile "xy";
                          let val ins = SML90.open_in file
                              val a = SML90.end_of_stream ins
                              val _ = SML90.input (ins, 1)
                              val b = SML90.end_of_stream ins
                              val _ = SML90.input (ins, 1)
                              val c = SML90.end_of_stream ins
                          in SML90.close_in ins; [a, b, c] end))
  val () = eqB ("SML90.end_of_stream/closed", true,
                fn () => (writeFile "xy";
                          let val ins = SML90.open_in file in SML90.close_in ins; SML90.end_of_stream ins end))
  val () = eqS ("SML90.close_in/then-input-is-empty", "",
                fn () => (writeFile "xy";
                          let val ins = SML90.open_in file in SML90.close_in ins; SML90.input (ins, 2) end))
  val () = T.check ("SML90.close_in/twice", fn () =>
                    (writeFile "xy"; let val ins = SML90.open_in file in SML90.close_in ins; SML90.close_in ins; true end))
  val () = T.raises ("SML90.output/Io-closed", isIo,
                     fn () => let val out = SML90.open_out file in SML90.close_out out; SML90.output (out, "x") end)
  val () = T.check ("SML90.close_out/twice", fn () =>
                    let val out = SML90.open_out file in SML90.close_out out; SML90.close_out out; true end)
  val () = eqS ("SML90.open_out/truncates", "new",
                fn () => (writeFile "old contents"; writeFile "new";
                          let val ins = SML90.open_in file in SML90.input (ins, 100) before SML90.close_in ins end))
  val () = T.raises ("SML90.open_in/Io-missing", isIo, fn () => SML90.open_in "no-such-directory/f")
  val () = T.raises ("SML90.open_out/Io-bad-directory", isIo, fn () => SML90.open_out "no-such-directory/f")
  val () = T.check ("SML90.std_in/is-open", fn () => (SML90.std_in; true))
  val () = T.check ("SML90.std_out/writes", fn () => (SML90.output (SML90.std_out, ""); true))
  (*>> streams *)
end
