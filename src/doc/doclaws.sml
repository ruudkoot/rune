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

  (* One law at one structure, as an entry of the program: its label and what
     makes its property, or what stops it from being run. `sides` is the law's
     two sides where it is an equation. *)
  fun entry (l : law, structure' : string, opens : string, result : DocElab.law, sides : (string * string) option) : string =
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
