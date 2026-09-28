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

  (* The arbitrary of a law's variables that draws each integer variable
     that its conditions bound from within the bounds, after the variables
     the bounds name (P14): the variables without bounds are drawn first,
     then each bounded one in order, from `Gen.intRange` of its bounds, which
     are evaluated under the structure's names. An empty range, or bounds
     that raise, discard the case, as a condition that raises does. NONE: no
     variable is bounded. *)
  fun domains (fixity : Fixity.env, opens : string, vars : (string * string * string) list, conditions : string list)
      : string option =
    let
      fun opened e = if opens = "" then "(" ^ e ^ ")" else "let open " ^ opens ^ " in " ^ e ^ " end"
      val bounded =
        List.mapPartial (fn (x, ty, _) =>
                           if ty <> "int" then NONE
                           else case boundsOf fixity x conditions of
                                  ([], []) => NONE
                                | b => SOME (x, b))
                        vars
      (* a bounded variable is drawn in order after the unbounded ones, and
         its bounds may name only those and the bounded ones before it *)
      fun order ([], _, acc) = List.rev acc
        | order ((x, (lows, highs)) :: rest, known, acc) =
            let
              val later = List.filter (fn (v, _, _) => not (List.exists (fn k => k = v) known) andalso v <> x) vars
              fun ok (e, _) = not (List.exists (fn (v, _, _) => mentions v e) later)
            in
              if List.all ok (lows @ highs) then order (rest, x :: known, (x, (lows, highs)) :: acc)
              else order (rest, known, acc)
            end
      val unbounded0 = List.filter (fn (v, _, _) => not (List.exists (fn (x, _) => x = v) bounded)) vars
      val drawnLate = order (bounded, List.map #1 unbounded0, [])
      val unbounded = List.filter (fn (v, _, _) => not (List.exists (fn (x, _) => x = v) drawnLate)) vars
    in
      if List.null drawnLate then NONE
      else
        let
          val (uarb, upat) = together (List.map (fn (v, _, a) => (v, a)) unbounded)
          val (arb, pat) = together (List.map (fn (v, _, a) => (v, a)) vars)
          fun lower [] = "valOf Int.minInt"
            | lower ls = List.foldl (fn (e, acc) => "Int.max (" ^ e ^ ", " ^ acc ^ ")") (hd ls) (tl ls)
          fun bound (e, strict, adjust) = if strict then "(" ^ e ^ ") " ^ adjust ^ " 1" else "(" ^ e ^ ")"
          fun range (lows, highs) =
            "(let val (lo, hi) = " ^ opened ("(" ^ (case lows of [] => "valOf Int.minInt"
                                                               | _ => lower (List.map (fn (e, s) => bound (e, s, "+")) lows))
                                          ^ ", " ^ (case highs of [] => "valOf Int.maxInt"
                                                                | (e0, s0) :: hs => List.foldl (fn (e, acc) => "Int.min (" ^ e ^ ", " ^ acc ^ ")")
                                                                                               (bound (e0, s0, "-"))
                                                                                               (List.map (fn (e, s) => bound (e, s, "-")) hs))
                                          ^ ")")
            ^ " handle _ => raise Gen.Discarded in if lo > hi then raise Gen.Discarded else Gen.intRange (lo, hi) end)"
          fun nest [] = "Gen.return " ^ pat
            | nest ((x, b) :: rest) = "Gen.bind " ^ range b ^ " (fn " ^ x ^ " => " ^ nest rest ^ ")"
        in
          SOME ("let val a = " ^ arb ^ " in {gen = Gen.bind (#gen (" ^ uarb ^ ")) (fn " ^ upat ^ " => " ^ nest drawnLate
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
