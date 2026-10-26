(* Faults made on purpose, for the negative tests of the lints (linting
   roadmap, M4; docs/testing.md): RUNE_FAULT=STAGE:KIND or STAGE:KIND@N
   corrupts what the stage STAGE made, at the N-th place of the kind (from
   0), before the stage's checks see it, so that each rule of each lint is
   shown to refuse what breaks it, on the compiler's own output, without a
   reader of every representation. It says on standard error what it did,
   `fault STAGE:KIND: WHAT`, or that it found no place; where RUNE_FAULT is
   unset, as in every compile but those tests, it is the identity. The
   stages: translate (Lambda); mid, midcanon and each optional pass on Mid;
   lower (Low). RegVerify has its own (RUNE_REGVERIFY_INJECT). The kinds,
   by representation, each aimed at a rule:
     Lambda: scope twice jump jump-out con select const-type const-kind
             const-range mkexn prim-name cast functor-cast dynamic-cast
             open-cast inst fail letrec global
     Mid:    scope twice jump jump-out type poly tyargs select con mkexn
             mkexn-copy prim-name const-kind const-range do-drop do-unset
             nary cast functor-cast dynamic-cast open-cast
     Low:    twice undef jump nojump pop push callk closure env rep select
   (select, a field past a tuple's, is for shapes to refuse: the
   roadmap's M6). *)
structure Fault =
struct
  fun spec () : (string * string * int) option =
    case OS.Process.getEnv "RUNE_FAULT" of
      NONE => NONE
    | SOME "" => NONE
    | SOME s =>
        case String.tokens (fn c => c = #":") s of
          [stage, k] =>
            (case String.tokens (fn c => c = #"@") k of
               [kind, n] => SOME (stage, kind, getOpt (Int.fromString n, 0))
             | _ => SOME (stage, k, 0))
        | _ => NONE

  fun say (stage, kind, what) =
    TextIO.output (TextIO.stdErr, "fault " ^ stage ^ ":" ^ kind ^ ": " ^ (if what = "" then "no place found" else what) ^ "\n")

  (* the places of the kind met so far: whether this one is the N-th, and
     what was done there *)
  fun counter n =
    let
      val seen = ref 0
      val did = ref ""
    in
      (fn what => if !did <> "" then false
                  else (seen := !seen + 1; if !seen - 1 = n then (did := what; true) else false),
       did)
    end

  (* a stamp no binder has *)
  val bogus = 999999937

  fun exnStamp (c : int) = isSome (Ty.exnArgOf c)
  fun copyStamp (c : int) = isSome (IntTable.find (Ty.exnCopies, c))
  fun isCast p = List.exists (fn c => c = p) IrRules.casts
  (* cast: any of the compiler's casts; functor-cast, dynamic-cast,
     open-cast: that one *)
  fun castOf (kind, p) = isCast p andalso (kind = "cast" orelse kind = String.map (fn #"_" => #"-" | c => c) p)

  (* ---- Lambda ---- *)
  structure L = Lambda
  fun otherPayload (stamp : int) : L.lexp =
    case Ty.exnArgOf stamp of
      SOME (SOME t) => if Ty.equal (t, Ty.string) then L.Const (L.CInt (IntInf.fromInt 7), Ty.int)
                       else L.Const (L.CString "fault", Ty.string)
    | _ => L.Const (L.CString "fault", Ty.string)
  fun lambda (stage : string, e : L.lexp) : L.lexp =
    case spec () of
      NONE => e
    | SOME (st, kind, n) =>
        if st <> stage then e
        else
          let
            val (hit, did) = counter n
            val firstBinder = ref ~1
            fun stampOf c = case L.unmark c of L.Var y => y | L.Global g => g | _ => ~1
            fun go e =
              case e of
                L.Var x => if kind = "scope" andalso hit "a variable made one not in scope" then L.Var bogus else e
              | L.Global g => if kind = "global" andalso hit "a global made one of no type" then L.Global bogus else e
              | L.Let (x, a, b) =>
                  if kind = "twice" then
                    if !firstBinder < 0 then (firstBinder := x; L.Let (x, go a, go b))
                    else if hit ("v" ^ Int.toString x ^ " made v" ^ Int.toString (!firstBinder)) then L.Let (!firstBinder, a, b)
                    else L.Let (x, go a, go b)
                  else L.Let (x, go a, go b)
              | L.Jump (j, args) =>
                  if kind = "jump" andalso hit "a jump given one argument more" then L.Jump (j, args @ [L.Unit])
                  else if kind = "jump-out" andalso hit "a jump made one to no join point in scope" then L.Jump (bogus, args)
                  else L.Jump (j, List.map go args)
              | L.Con (tag, t, a) =>
                  if kind = "con" andalso hit "a constructor's tag made one its datatype has not" then L.Con (tag + 100, t, a)
                  else L.Con (tag, t, go a)
              | L.Const (c as L.CInt i, t) =>
                  if kind = "const-type" andalso Ty.equal (t, Ty.int) andalso hit "an int constant given type string"
                  then L.Const (c, Ty.string)
                  else if kind = "const-kind" andalso Ty.equal (t, Ty.int) andalso hit "an int constant made a word of type int"
                  then L.Const (L.CWord (IntInf.abs i), t)
                  else if kind = "const-range" andalso Ty.equal (t, Ty.int) andalso hit "an int constant made one beyond 63 bits"
                  then L.Const (L.CInt (IntInf.pow (IntInf.fromInt 2, 70)), t)
                  else e
              | L.MkExn (c, p) =>
                  if kind = "mkexn" andalso exnStamp (stampOf c) andalso hit "an exception's payload made another type"
                  then L.MkExn (c, otherPayload (stampOf c))
                  else L.MkExn (go c, go p)
              | L.Prim (p, t, args) =>
                  if kind = "prim-name" andalso p = "int_add" andalso hit "int_add made word_add at its type"
                  then L.Prim ("word_add", t, args)
                  else if castOf (kind, p) andalso hit (p ^ " made from string to int")
                  then L.Prim (p, SOME (Ty.arrow (Ty.string, Ty.int)), args)
                  else L.Prim (p, t, List.map go args)
              | L.Inst (a, t) =>
                  if kind = "inst" andalso hit "a use at an instance made one at no instance" then L.Inst (a, Ty.exn)
                  else L.Inst (go a, t)
              | L.Fn (x, t, b) =>
                  if kind = "fail" andalso hit "a function's body given a Fail first" then L.Fn (x, t, L.Seq (L.Fail, b))
                  else L.Fn (x, t, go b)
              | L.LetRec (bs, b) =>
                  if kind = "letrec" andalso hit "a letrec's function made unit" then L.LetRec (List.map (fn (x, t, _) => (x, t, L.Unit)) bs, b)
                  else L.LetRec (List.map (fn (x, t, r) => (x, t, go r)) bs, go b)
              | L.App (f, a) => let val f = go f in L.App (f, go a) end
              | L.Seq (a, b) => let val a = go a in L.Seq (a, go b) end
              | L.SetGlobal (g, a) => L.SetGlobal (g, go a)
              | L.Tuple es => L.Tuple (List.map go es)
              | L.Select (i, a) =>
                  if kind = "select" andalso hit "a field made one past the tuple's" then L.Select (i + 5, a) else L.Select (i, go a)
              | L.Decon (tag, a) => L.Decon (tag, go a)
              | L.ConTag a => L.ConTag (go a)
              | L.If (c, t, f) => let val c = go c val t = go t in L.If (c, t, go f) end
              | L.Try (a, b) => let val a = go a in L.Try (a, go b) end
              | L.Join (j, ps, b, s) => let val b = go b in L.Join (j, ps, b, go s) end
              | L.Raise a => L.Raise (go a)
              | L.Handle (a, x, h) => let val a = go a in L.Handle (a, x, go h) end
              | L.ExnCon a => L.ExnCon (go a)
              | L.ExnArg (t, a) => L.ExnArg (t, go a)
              | L.Mark (sp, a) => L.Mark (sp, go a)
              | L.Rest a => L.Rest (go a)
              | _ => e
            val e' = go e
          in say (stage, kind, !did); e' end

  (* ---- Mid ---- *)
  structure M = Mid
  fun mid (stage : string, p : M.program) : M.program =
    case spec () of
      NONE => p
    | SOME (st, kind, n) =>
        if st <> stage then p
        else
          let
            val (hit, did) = counter n
            val firstLet = ref ~1
            fun stampOf c = case c of M.Var (y, _) => y | M.Global (g, _) => g | _ => ~1
            (* poly: the binders some use gives types, whose losing their
               variables a use shows (the rule that no type variable is
               free, which would see it anywhere, is M5's) *)
            val instantiated : unit IntTable.table = IntTable.table 64
            fun noteAtom a =
              case a of
                M.Var (x, _ :: _) => IntTable.insert (instantiated, x, ())
              | M.Global (x, _ :: _) => IntTable.insert (instantiated, x, ())
              | _ => ()
            fun noteRhs r =
              case r of
                M.Atom a => noteAtom a
              | M.App (f, xs) => List.app noteAtom (f :: xs)
              | M.Prim (_, _, xs) => List.app noteAtom xs
              | M.Tuple xs => List.app noteAtom xs
              | M.Select (_, a) => noteAtom a
              | M.Con (_, _, a) => noteAtom a
              | M.Decon (_, _, a) => noteAtom a
              | M.ConTag a => noteAtom a
              | M.MkExn (c, a) => (noteAtom c; noteAtom a)
              | M.ExnCon a => noteAtom a
              | M.ExnArg (_, a) => noteAtom a
              | M.SetGlobal (_, a) => noteAtom a
              | _ => ()
            fun noteExp e =
              case e of
                M.Let (_, _, r, b) => (noteRhs r; noteExp b)
              | M.Fun (fs, b) => (List.app (fn f => noteExp (#body f)) fs; noteExp b)
              | M.Join (_, _, b, sc) => (noteExp b; noteExp sc)
              | M.Jump (_, xs) => List.app noteAtom xs
              | M.If (c, t, f) => (noteAtom c; noteExp t; noteExp f)
              | M.Handle (a, _, h) => (noteExp a; noteExp h)
              | M.Raise a => noteAtom a
              | M.Return r => noteRhs r
              | M.Mark (_, a) => noteExp a
            val () =
              if kind <> "poly" then ()
              else List.app (fn M.Val (_, _, e) => noteExp e | M.Funs fs => List.app (fn f => noteExp (#body f)) fs | M.Do (_, e) => noteExp e) p
            fun used x = isSome (IntTable.find (instantiated, x))
            fun atom a =
              case a of
                M.Var (x, args) =>
                  if kind = "scope" andalso hit "a variable made one not in scope" then M.Var (bogus, args)
                  else if kind = "tyargs" andalso not (null args) andalso hit ("v" ^ Int.toString x ^ " given one type fewer")
                  then M.Var (x, tl args)
                  else a
              | M.Global (g, args) =>
                  if kind = "tyargs" andalso not (null args) andalso hit ("g" ^ Int.toString g ^ " given one type fewer")
                  then M.Global (g, tl args)
                  else a
              | M.Const (c as Lambda.CInt i, t) =>
                  if kind = "const-kind" andalso Ty.equal (t, Ty.int) andalso hit "an int constant made a word of type int"
                  then M.Const (Lambda.CWord (IntInf.abs i), t)
                  else if kind = "const-range" andalso Ty.equal (t, Ty.int) andalso hit "an int constant made one beyond 63 bits"
                  then M.Const (Lambda.CInt (IntInf.pow (IntInf.fromInt 2, 70)), t)
                  else a
              | _ => a
            fun rhs r =
              case r of
                M.Atom a => M.Atom (atom a)
              | M.App (f, xs) => M.App (atom f, List.map atom xs)
              | M.Prim (name, t, xs) =>
                  if kind = "prim-name" andalso name = "int_add" andalso hit "int_add made word_add at its type"
                  then M.Prim ("word_add", t, xs)
                  else if castOf (kind, name) andalso hit (name ^ " made from string to int")
                  then M.Prim (name, Ty.arrow (Ty.string, Ty.int), xs)
                  else M.Prim (name, t, List.map atom xs)
              | M.Tuple xs => M.Tuple (List.map atom xs)
              | M.Select (i, a) =>
                  if kind = "select" andalso hit "a field made one past the tuple's" then M.Select (i + 5, a) else M.Select (i, atom a)
              | M.Con (tag, t, a) =>
                  if kind = "con" andalso hit "a constructor's tag made one its datatype has not" then M.Con (tag + 100, t, a)
                  else M.Con (tag, t, atom a)
              | M.Decon (tag, t, a) => M.Decon (tag, t, atom a)
              | M.ConTag a => M.ConTag (atom a)
              | M.MkExn (c, a) =>
                  if (kind = "mkexn" andalso exnStamp (stampOf c) orelse kind = "mkexn-copy" andalso copyStamp (stampOf c))
                     andalso hit "an exception's payload made another type"
                  then M.MkExn (c, case otherPayload (stampOf c) of L.Const (k, t) => M.Const (k, t) | _ => M.Unit)
                  else M.MkExn (atom c, atom a)
              | M.ExnCon a => M.ExnCon (atom a)
              | M.ExnArg (t, a) => M.ExnArg (t, atom a)
              | M.SetGlobal (g, a) => M.SetGlobal (g, atom a)
              | _ => r
            fun exp e =
              case e of
                M.Let (x, s as (tvs, t), r, b) =>
                  if kind = "twice" andalso !firstLet < 0 then (firstLet := x; M.Let (x, s, rhs r, exp b))
                  else if kind = "twice" andalso hit ("v" ^ Int.toString x ^ " made v" ^ Int.toString (!firstLet))
                  then M.Let (!firstLet, s, r, b)
                  else if kind = "type" andalso null tvs andalso Ty.equal (t, Ty.int) andalso hit ("v" ^ Int.toString x ^ " of int given type string")
                  then M.Let (x, (tvs, Ty.string), r, b)
                  else if kind = "poly" andalso not (null tvs) andalso used x andalso hit ("v" ^ Int.toString x ^ "'s scheme made to bind no type variable")
                  then M.Let (x, ([], t), r, exp b)
                  else M.Let (x, s, rhs r, exp b)
              | M.Fun (fs, b) => M.Fun (List.map fundef fs, exp b)
              | M.Join (j, ps, body, scope) => M.Join (j, ps, exp body, exp scope)
              | M.Jump (j, xs) =>
                  if kind = "jump" andalso hit "a jump given one argument more" then M.Jump (j, xs @ [M.Unit])
                  else if kind = "jump-out" andalso hit "a jump made one to no join point in scope" then M.Jump (bogus, xs)
                  else M.Jump (j, List.map atom xs)
              | M.If (c, t, f) => M.If (atom c, exp t, exp f)
              | M.Handle (a, x, h) => M.Handle (exp a, x, exp h)
              | M.Raise a => M.Raise (atom a)
              | M.Return r => M.Return (rhs r)
              | M.Mark (pos, a) => M.Mark (pos, exp a)
            and fundef (f : M.fundef) =
              {name = #name f,
               tyvars = if kind = "poly" andalso not (null (#tyvars f)) andalso used (#name f)
                           andalso hit ("function v" ^ Int.toString (#name f) ^ " made to bind no type variable")
                        then [] else #tyvars f,
               params = #params f, result = #result f, body = exp (#body f)}
            (* a Do's expression with its first SetGlobal made unit *)
            fun unsetIt g = hit ("g" ^ Int.toString g ^ " no longer set by its Do")
            fun unset e =
              case e of
                M.Let (x, s, r as M.SetGlobal (g, _), b) =>
                  if unsetIt g then M.Let (x, s, M.Atom M.Unit, b) else M.Let (x, s, r, unset b)
              | M.Let (x, s, r, b) => M.Let (x, s, r, unset b)
              | M.Fun (fs, b) => M.Fun (fs, unset b)
              | M.Join (j, ps, body, scope) => let val body = unset body in M.Join (j, ps, body, unset scope) end
              | M.If (c, t, f) => let val t = unset t in M.If (c, t, unset f) end
              | M.Handle (a, x, h) => let val a = unset a in M.Handle (a, x, unset h) end
              | M.Mark (pos, a) => M.Mark (pos, unset a)
              | M.Return (M.SetGlobal (g, _)) => if unsetIt g then M.Return (M.Atom M.Unit) else e
              | _ => e
            fun def d =
              case d of
                M.Val (g, s, e) => M.Val (g, s, exp e)
              | M.Funs fs => M.Funs (List.map fundef fs)
              | M.Do (gs, e) =>
                  if kind = "do-drop" andalso not (null gs) andalso hit ("g" ^ Int.toString (#1 (hd gs)) ^ " dropped from its Do's list")
                  then M.Do (tl gs, e)
                  else if kind = "do-unset" andalso not (null gs) then M.Do (gs, unset e)
                  else M.Do (gs, exp e)
            val p' = List.map def p
            (* nary: a function of two parameters used as a value *)
            val p' =
              if kind <> "nary" then p'
              else
                case List.find (fn M.Funs fs => List.exists (fn f => List.length (#params f) = 2 andalso null (#tyvars f)) fs | _ => false) p' of
                  SOME (M.Funs fs) =>
                    let val f = valOf (List.find (fn f => List.length (#params f) = 2 andalso null (#tyvars f)) fs)
                    in
                      if hit ("v" ^ Int.toString (#name f) ^ ", of two parameters, used as a value")
                      then p' @ [M.Val (bogus + 1, ([], M.funTy f), M.Return (M.Atom (M.Global (#name f, []))))]
                      else p'
                    end
                | _ => p'
          in say (stage, kind, !did); p' end

  (* ---- Low ---- *)
  structure W = Low
  fun low (stage : string, p : W.program) : W.program =
    case spec () of
      NONE => p
    | SOME (st, kind, n) =>
        if st <> stage then p
        else
          let
            val (hit, did) = counter n
            fun block (f : W.func) ({label, params, instrs, transfer} : W.block) : W.block =
              let
                fun instr i =
                  case i of
                    W.Def (x, oper) =>
                      (case oper of
                         W.CallK (g, vs as _ :: _) =>
                           if kind = "callk" andalso hit "a known call given one argument more" then [W.Def (x, W.CallK (g, vs @ [hd vs]))] else [i]
                       | W.Closure (g, vs) =>
                           if kind = "closure" andalso hit "a closure given one value more to capture" then [W.Def (x, W.Closure (g, vs @ [NONE]))]
                           else [i]
                       | W.Env k =>
                           if kind = "env" andalso hit "an Env out of the closure's range" then [W.Def (x, W.Env (k + 7))] else [i]
                       | W.Select (k, v) =>
                           if kind = "select" andalso hit "a Select of a field the tuple has not"
                           then [W.Def (x, W.Select (k + 5, v))] else [i]
                       | _ =>
                           if kind = "twice" andalso hit ("v" ^ Int.toString x ^ " defined twice") then [i, i]
                           else if kind = "undef" andalso (case oper of W.Tuple (_ :: _) => true | W.Prim (_, _ :: _) => true | _ => false)
                                   andalso hit "a use made of a variable defined nowhere"
                           then [W.Def (x, case oper of
                                             W.Tuple (_ :: vs) => W.Tuple (#nvars f + 3 :: vs)
                                           | W.Prim (pn, _ :: vs) => W.Prim (pn, #nvars f + 3 :: vs)
                                           | o' => o')]
                           else [i])
                  | _ => [i]
                val instrs = List.concat (List.map instr instrs)
                val entry = label = #label (hd (#blocks f))
                val instrs = if kind = "pop" andalso entry andalso hit "a pop with no handler at a function's entry"
                             then W.Pop :: instrs else instrs
                val transfer' =
                  case transfer of
                    W.Goto (l, vs as _ :: _) =>
                      if kind = "jump" andalso hit "a jump given one argument more" then W.Goto (l, vs @ [hd vs])
                      else if kind = "nojump" andalso hit "a jump to no block" then W.Goto (bogus, vs) else transfer
                  | _ => transfer
                (* push: a handler pushed and left pushed at a return *)
                val instrs =
                  case (transfer', kind) of
                    (W.Return _, "push") =>
                      (case List.find (fn ({params = [_], label = l, ...} : W.block) => l <> label | _ => false) (#blocks f) of
                         SOME {label = h, ...} => if hit "a handler pushed and left pushed at a return" then instrs @ [W.Push h] else instrs
                       | NONE => instrs)
                  | _ => instrs
              in {label = label, params = params, instrs = instrs, transfer = transfer'} end
            fun func (f : W.func) : W.func =
              let
                val blocks = List.map (block f) (#blocks f)
                (* rep: a variable an int constant makes given ptr *)
                val reps =
                  if kind <> "rep" then #reps f
                  else
                    case List.find (fn (W.Def (x, W.Const (Lambda.CInt _))) => true | _ => false) (List.concat (List.map #instrs blocks)) of
                      SOME (W.Def (x, _)) =>
                        if hit ("v" ^ Int.toString x ^ ", an int, given rep ptr") then Vector.mapi (fn (y, r) => if y = x then W.RPtr else r) (#reps f)
                        else #reps f
                    | _ => #reps f
              in
                {id = #id f, name = #name f, params = #params f, ncaptured = #ncaptured f, nvars = #nvars f + 4,
                 blocks = blocks, pos = #pos f,
                 reps = Vector.tabulate (#nvars f + 4, fn y => if y < Vector.length reps then Vector.sub (reps, y) else W.RAny),
                 result = #result f, captures = #captures f}
              end
            val p' = List.map func p
          in say (stage, kind, !did); p' end
end
