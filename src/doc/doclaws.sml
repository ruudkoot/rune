(* Laws that are elaborated, and run (docs/plans/quickcheck.md, D6, D7, M7
   and M8). A `Law:` paragraph is read by a small grammar over its pieces of
   code and the words around them:

   - the first piece of code is a law, and so is one after "and" that follows
     a law: "Law: `l1`, and `l2`";
   - a piece after "for" or "when" is a condition, a `bool` in Standard ML,
     and so is one after "and" that follows a condition;
   - "for `x` from `G`" gives the variable `x` the arbitrary `G`;
   - "when `f` has no effects" draws the function `f` from the pure ones;
   - any other piece is prose: a name or a result the sentence speaks of.

   The conditions of a paragraph hold for each of its laws. A law is read as
   the examples are, under `open S` for the structure the examples are read
   in, and the names it leaves unbound are its variables, which the law
   holds for. Where the law is an equation, `l = r`, its two sides are
   compared by outcome: equal values, or the same exception (D6). *)
structure DocLaws =
struct
  structure I = DocIR
  structure T = DocText

  type law = {signat : string,
              member : string,              (* with its substructures *)
              path : string list,           (* the substructures *)
              index : int,                  (* the member's laws are numbered from 1 *)
              name : string option,         (* `Law (Associative):`, with a number where its paragraph has several *)
              code : string,                (* the law as written *)
              conditions : string list,
              domains : (string * string) list,
              pure : string list,
              span : Source.span}

  open DocLawGrammar

  fun ofDoc (signat, member, path, span) (doc : I.doc) : law list =
    let
      val paragraphs = List.mapPartial (fn T.Reserved {keyword = "Law", modifier, body} => SOME (modifier, body) | _ => NONE) doc
      fun lawsOf (modifier, body) =
        let
          val rs = roles body
          val conditions = List.mapPartial (fn (c, Condition) => SOME c | _ => NONE) rs
          val domains = List.mapPartial (fn (x, Domain g) => SOME (x, g) | _ => NONE) rs
          val pure = List.mapPartial (fn (f, Pure) => SOME f | _ => NONE) rs
          val laws = List.mapPartial (fn (c, Law) => SOME c | _ => NONE) rs
          fun named k = case (modifier, laws) of
                          (NONE, _) => NONE
                        | (SOME m, [_]) => SOME m
                        | (SOME m, _) => SOME (m ^ " " ^ Int.toString k)
        in
          ListPair.map (fn (c, k) => (c, conditions, domains, pure, named k)) (laws, List.tabulate (List.length laws, fn k => k + 1))
        end
      val all = List.concat (List.map lawsOf paragraphs)
    in
      ListPair.map (fn ((code, conditions, domains, pure, name), index) =>
                      {signat = signat, member = member, path = path, index = index, name = name, code = code,
                       conditions = conditions, domains = domains, pure = pure, span = span})
                   (all, List.tabulate (List.length all, fn i => i + 1))
    end

  fun ofSignature (s : I.signatureRecord) : law list =
    List.concat (List.map (fn e : I.entryRecord =>
                             ofDoc (#name s, String.concatWith "." (#path e @ [#name e]), #path e, #span e) (#doc e))
                          (DocPage.entriesOf (#body s)))

  (* A law's name in a label: its letters and digits, lower case, the rest
     a hyphen. *)
  fun slug (name : string) : string =
    String.concatWith "-" (String.tokens (fn c => not (Char.isAlphaNum c)) (String.map Char.toLower name))

  (* The label of a law, as the Basis suite labels its checks (D13):
     `INTEGER.div/law-1`, or by its name, `GENERAL.o/law-associative`. *)
  fun label ({signat, member, index, name, ...} : law) : string =
    signat ^ "." ^ member ^ "/law-" ^ (case name of SOME n => slug n | NONE => Int.toString index)

  (* `open S S.Sub ...`: what a law of a member of a substructure is read under *)
  fun opens (structure' : string, path : string list) : string =
    let
      fun prefixes ([], _) = []
        | prefixes (p :: ps, sofar) = (sofar ^ "." ^ p) :: prefixes (ps, sofar ^ "." ^ p)
    in
      String.concatWith " " (structure' :: prefixes (path, structure'))
    end

  (* The laws that elaborated, with their variables: what the pages show and
     --laws runs. *)
  val elaborated : (law * DocElab.variable list) list ref = ref []

  (* ---- the programs of --laws (quickcheck M8) ---- *)

  fun str (s : string) : string = "\"" ^ String.toString s ^ "\""

  (* whether a type, as printed, has a function type in it: its values have
     no equality, and printing them says nothing, so a law must compare
     their calls (D6) *)
  fun hasFunction (ty : string) : bool = String.isSubstring "->" ty

  (* An arbitrary of the variables together and the pattern that binds them:
     a pair or triple, pairs nested beyond three, `()` for none. *)
  fun together (vars : (string * string) list) : string * string =
    case vars of
      [] => ("Arb.unit", "()")
    | [(v, a)] => (a, v)
    | [(v, a), (w, b)] => ("Arb.pair (" ^ a ^ ", " ^ b ^ ")", "(" ^ v ^ ", " ^ w ^ ")")
    | [(v, a), (w, b), (x, c)] => ("Arb.triple (" ^ a ^ ", " ^ b ^ ", " ^ c ^ ")", "(" ^ v ^ ", " ^ w ^ ", " ^ x ^ ")")
    | (v, a) :: rest =>
        let val (r, p) = together rest
        in ("Arb.pair (" ^ a ^ ", " ^ r ^ ")", "(" ^ v ^ ", " ^ p ^ ")") end

  (* ---- drawing into the conditions (P14) ---- *)

  (* the pieces of a condition that `andalso` joins at its top: outside
     brackets, strings and `let ... end` *)
  fun conjuncts (c : string) : string list =
    let
      val n = String.size c
      fun word (i, w) = String.isPrefix w (String.extract (c, i, NONE))
                        andalso (i = 0 orelse not (Char.isAlphaNum (String.sub (c, i - 1))))
                        andalso (i + String.size w >= n orelse not (Char.isAlphaNum (String.sub (c, i + String.size w))))
      fun go (i, depth, start, acc) =
        if i >= n then List.rev (String.substring (c, start, n - start) :: acc)
        else
          case String.sub (c, i) of
            #"(" => go (i + 1, depth + 1, start, acc) | #"[" => go (i + 1, depth + 1, start, acc)
          | #"{" => go (i + 1, depth + 1, start, acc)
          | #")" => go (i + 1, depth - 1, start, acc) | #"]" => go (i + 1, depth - 1, start, acc)
          | #"}" => go (i + 1, depth - 1, start, acc)
          | #"\"" => let fun skip j = if j >= n then n else if String.sub (c, j) = #"\\" then skip (j + 2)
                                        else if String.sub (c, j) = #"\"" then j + 1 else skip (j + 1)
                     in go (skip (i + 1), depth, start, acc) end
          | _ =>
              if word (i, "let") then go (i + 3, depth + 1, start, acc)
              else if word (i, "end") then go (i + 3, depth - 1, start, acc)
              else if depth = 0 andalso word (i, "andalso")
              then go (i + 7, depth, i + 7, String.substring (c, start, i - start) :: acc)
              else go (i + 1, depth, start, acc)
    in
      List.map (fn t => Substring.string (Substring.dropr Char.isSpace (Substring.dropl Char.isSpace (Substring.full t))))
               (go (0, 0, 0, []))
    end

  (* whether the name occurs in the text as a word of its own *)
  fun mentions (name : string) (t : string) : bool =
    List.exists (fn w => w = name) (String.tokens (fn c => not (Char.isAlphaNum c orelse c = #"_" orelse c = #"'")) t)

  (* The bounds a condition sets on the integer variable x: lower and upper,
     each an expression and whether it is strict. *)
  fun boundsOf (fixity : Fixity.env) (x : string) (conditions : string list)
      : (string * bool) list * (string * bool) list =
    List.foldl (fn (c, (lows, highs)) =>
                  case DocElab.infixSplit fixity ["<", "<=", ">", ">="] c of
                    SOME (l, opr, r) =>
                      if l = x andalso not (mentions x r) then
                        (case opr of
                           "<" => (lows, highs @ [(r, true)]) | "<=" => (lows, highs @ [(r, false)])
                         | ">" => (lows @ [(r, true)], highs) | _ => (lows @ [(r, false)], highs))
                      else if r = x andalso not (mentions x l) then
                        (case opr of
                           "<" => (lows @ [(l, true)], highs) | "<=" => (lows @ [(l, false)], highs)
                         | ">" => (lows, highs @ [(l, true)]) | _ => (lows, highs @ [(l, false)]))
                      else (lows, highs)
                  | NONE => (lows, highs))
               ([], []) (List.concat (List.map conjuncts conditions))

  (* The arbitrary of a law's variables that draws each variable its
     conditions pin down from within them (P14): an integer variable that
     they bound from within the bounds, `Gen.intRange` of the bounds, which
     are evaluated under the structure's names; and a variable that a
     condition `x = y` equates with another of its type as that other one.
     Those are drawn after the variables their bounds name, the others first.
     An empty range, or bounds that raise, discard the case, as a condition
     that raises does. NONE: no variable is pinned down. *)
  fun domains (fixity : Fixity.env, opens : string, vars : (string * string * string) list, conditions : string list)
      : string option =
    let
      fun opened e = if opens = "" then "(" ^ e ^ ")" else "let open " ^ opens ^ " in " ^ e ^ " end"
      fun tyOf v = case List.find (fn (w, _, _) => w = v) vars of SOME (_, t, _) => SOME t | NONE => NONE
      (* y = x: y drawn as x, the earlier of the two in the law *)
      val aliases =
        List.foldl (fn (c, acc) =>
                      case DocElab.infixSplit fixity ["="] c of
                        SOME (l, _, r) =>
                          if l <> r andalso isSome (tyOf l) andalso tyOf l = tyOf r
                             andalso not (List.exists (fn (y, _) => y = l orelse y = r) acc)
                          then (r, l) :: acc else acc
                      | NONE => acc)
                   [] (List.concat (List.map conjuncts conditions))
      fun lower [] = "valOf Int.minInt"
        | lower (l :: ls) = List.foldl (fn (e, acc) => "Int.max (" ^ e ^ ", " ^ acc ^ ")") l ls
      fun upper [] = "valOf Int.maxInt"
        | upper (h :: hs) = List.foldl (fn (e, acc) => "Int.min (" ^ e ^ ", " ^ acc ^ ")") h hs
      fun bound (e, strict, adjust) = if strict then "(" ^ e ^ ") " ^ adjust ^ " 1" else "(" ^ e ^ ")"
      fun range (lows, highs) =
        "(let val (lo, hi) = " ^ opened ("(" ^ lower (List.map (fn (e, st) => bound (e, st, "+")) lows) ^ ", "
                                          ^ upper (List.map (fn (e, st) => bound (e, st, "-")) highs) ^ ")")
        ^ " handle _ => raise Gen.Discarded in if lo > hi then raise Gen.Discarded else Gen.intRange (lo, hi) end)"
      (* each variable drawn late: as another, or within bounds *)
      datatype how = Alias of string | Bounds of (string * bool) list * (string * bool) list
      val late =
        List.mapPartial (fn (x, ty, _) =>
                           case List.find (fn (y, _) => y = x) aliases of
                             SOME (_, other) => SOME (x, Alias other)
                           | NONE =>
                               if ty <> "int" then NONE
                               else case boundsOf fixity x conditions of
                                      ([], []) => NONE
                                    | b => SOME (x, Bounds b))
                        vars
      fun exprs (Alias other) = [other]
        | exprs (Bounds (lows, highs)) = List.map #1 (lows @ highs)
      fun gen (Alias other) = "(Gen.return " ^ other ^ ")"
        | gen (Bounds b) = range b
      (* the variables of rest that x's generator names *)
      fun deps rest (x, h) = List.filter (fn (v, _) => v <> x andalso List.exists (mentions v) (exprs h)) rest
      (* whether w's generator names x, through those of rest *)
      fun reaches rest (w, x) =
        let
          fun go (_, []) = false
            | go (seen, v :: todo) =
                if v = x then true
                else if List.exists (fn s => s = v) seen then go (seen, todo)
                else case List.find (fn (y, _) => y = v) rest of
                       SOME e => go (v :: seen, List.map #1 (deps rest e) @ todo)
                     | NONE => go (v :: seen, todo)
        in
          go ([], [w])
        end
      (* in order, each after the variables its generator names. Where those
         left name each other in a cycle, as `0 <= i andalso i < n andalso n
         <= maxLen` does, the cycle is broken at the first of them in the law:
         it keeps the bounds that name no variable of the cycle, `n <= maxLen`,
         and one that is such a variable gives way to that variable's own,
         `0 < n`. One left with none is drawn first, as if it had no bounds. *)
      fun order ([], acc) = List.rev acc
        | order (rest, acc) =
            case List.find (fn e => List.null (deps rest e)) rest of
              SOME (x, h) => order (List.filter (fn (y, _) => y <> x) rest, (x, h) :: acc)
            | NONE =>
                let
                  fun cycle e = List.filter (fn (w, _) => reaches rest (w, #1 e)) (deps rest e)
                  val (x, h) = valOf (List.find (not o List.null o cycle) rest)
                  val cyc = cycle (x, h)
                  fun names e = List.exists (fn (w, _) => mentions w e) cyc
                  (* a bound that is a variable of the cycle gives way to that
                     variable's own bounds on the same side that name none of
                     it: x > i and i >= 0 give x > 0 *)
                  fun through side (e, strict) =
                    if not (names e) then [(e, strict)]
                    else case List.find (fn (w, _) => w = e) rest of
                           SOME (_, Bounds b) =>
                             List.map (fn (e', strict') => (e', strict orelse strict'))
                                      (List.filter (fn (e', _) => not (names e' orelse mentions x e')) (side b))
                         | _ => []
                  val kept = case h of
                               Alias _ => NONE
                             | Bounds (lows, highs) =>
                                 (case (List.concat (List.map (through #1) lows),
                                        List.concat (List.map (through #2) highs)) of
                                    ([], []) => NONE
                                  | b => SOME (Bounds b))
                in
                  case kept of
                    SOME h' => order (List.map (fn (y, g) => if y = x then (y, h') else (y, g)) rest, acc)
                  | NONE => order (List.filter (fn (y, _) => y <> x) rest, acc)
                end
      val drawnLate = List.map (fn (x, h) => (x, gen h)) (order (late, []))
      val early = List.filter (fn (v, _, _) => not (List.exists (fn (x, _) => x = v) drawnLate)) vars
    in
      if List.null drawnLate then NONE
      else
        let
          val (earb, epat) = together (List.map (fn (v, _, a) => (v, a)) early)
          val (arb, pat) = together (List.map (fn (v, _, a) => (v, a)) vars)
          fun nest [] = "Gen.return " ^ pat
            | nest ((x, g) :: rest) = "Gen.bind " ^ g ^ " (fn " ^ x ^ " => " ^ nest rest ^ ")"
        in
          SOME ("let val a = " ^ arb ^ " in {gen = Gen.bind (#gen (" ^ earb ^ ")) (fn " ^ epat ^ " => " ^ nest drawnLate
                ^ "), show = #show a, co = #co a, eq = #eq a} end")
        end
    end

  (* One law at one structure, as an entry of the program: its label and what
     makes its property, or what stops it from being run. `sides` is the law's
     two sides where it is an equation. *)
  fun entry (l : law, structure' : string, opens : string, result : DocElab.law, sides : (string * string) option,
             fixity : Fixity.env) : string =
    let
      val name = label l ^ "@" ^ structure'
      fun broken why = "  (" ^ str name ^ ", fn () => raise Fail " ^ str why ^ ")"
      fun opened e = if opens = "" then "(" ^ e ^ ")" else "let open " ^ opens ^ " in " ^ e ^ " end"
    in
      case result of
        DocElab.NotSml msg => broken ("the law is no Standard ML at " ^ structure' ^ ": " ^ msg)
      | DocElab.Quantified (vars, side) =>
          case List.find (fn v : DocElab.variable => not (isSome (#instance v))) vars of
            SOME v => broken ("lib/test/property has no arbitrary of " ^ #name v ^ " : " ^ #ty v)
          | NONE =>
              let
                (* a variable with a domain, "for `x` from `G`", is drawn from G (D7) *)
                val vars = List.map (fn v as {name, ty, ...} : DocElab.variable =>
                                       case List.find (fn (x, _) => x = name) (#domains l) of
                                         SOME (_, g) => {name = name, ty = ty ^ " from " ^ g, instance = SOME ("(" ^ g ^ ")")}
                                       | NONE => v)
                                    vars
                val (arb, pat) = together (List.map (fn {name, instance, ...} : DocElab.variable => (name, valOf instance)) vars)
                (* the integer variables its conditions bound are drawn within the bounds (P14) *)
                val arb = case domains (fixity, opens,
                                        List.map (fn {name, ty, instance} : DocElab.variable => (name, ty, valOf instance)) vars,
                                        #conditions l) of
                            SOME d => d
                          | NONE => arb
                val cond = case #conditions l of
                             [] => "fn _ => true"
                           | cs => "fn " ^ pat ^ " => " ^ opened (String.concatWith " andalso " (List.map (fn c => "(" ^ c ^ ")") cs))
              in
                case (sides, side) of
                  (SOME (left, right), SOME {ty, instance, ...}) =>
                    if hasFunction ty then broken ("the law compares functions (" ^ ty ^ "): apply both sides to a variable")
                    else
                      (case instance of
                         SOME b =>
                           "  (" ^ str name ^ ",\n   fn () => Prop.equalIf (" ^ arb ^ ", " ^ b ^ ")\n     (" ^ cond
                           ^ ",\n      fn " ^ pat ^ " => " ^ opened left ^ ",\n      fn " ^ pat ^ " => " ^ opened right ^ "))"
                       | NONE => broken ("lib/test/property has no arbitrary of the sides' type " ^ ty))
                | _ =>
                    "  (" ^ str name ^ ",\n   fn () => Prop.holdsIf (" ^ arb ^ ")\n     (" ^ cond
                    ^ ",\n      fn " ^ pat ^ " => " ^ opened (#code l) ^ "))"
              end
    end

  (* The program that holds the laws of one signature at every structure that
     implements it, run by `Check.laws`. *)
  fun program (signat : string, file : string, entries : string list) : string =
    "(* The laws of the documentation of " ^ signat ^ ", at every structure that implements it.\n"
    ^ "   Generated by runedoc from " ^ file ^ "; do not edit. Compile it with\n"
    ^ "   `rune --library test/property` (docs/plans/quickcheck.md, M8). *)\n"
    ^ "val () = Check.laws [\n" ^ String.concatWith ",\n" entries ^ "]\n"
end
