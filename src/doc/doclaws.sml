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
              code : string,                (* the law as written *)
              conditions : string list,
              domains : (string * string) list,
              pure : string list,
              span : Source.span}

  open DocLawGrammar

  fun ofDoc (signat, member, path, span) (doc : I.doc) : law list =
    let
      val paragraphs = List.mapPartial (fn T.Reserved {keyword = "Law", body, ...} => SOME body | _ => NONE) doc
      fun lawsOf body =
        let
          val rs = roles body
          val conditions = List.mapPartial (fn (c, Condition) => SOME c | _ => NONE) rs
          val domains = List.mapPartial (fn (x, Domain g) => SOME (x, g) | _ => NONE) rs
          val pure = List.mapPartial (fn (f, Pure) => SOME f | _ => NONE) rs
        in
          List.mapPartial (fn (c, Law) => SOME (c, conditions, domains, pure) | _ => NONE) rs
        end
      val all = List.concat (List.map lawsOf paragraphs)
    in
      ListPair.map (fn ((code, conditions, domains, pure), index) =>
                      {signat = signat, member = member, path = path, index = index, code = code,
                       conditions = conditions, domains = domains, pure = pure, span = span})
                   (all, List.tabulate (List.length all, fn i => i + 1))
    end

  fun ofSignature (s : I.signatureRecord) : law list =
    List.concat (List.map (fn e : I.entryRecord =>
                             ofDoc (#name s, String.concatWith "." (#path e @ [#name e]), #path e, #span e) (#doc e))
                          (DocPage.entriesOf (#body s)))

  (* The label of a law, as the Basis suite labels its checks (D13):
     `INTEGER.div/law-1`. *)
  fun label ({signat, member, index, ...} : law) : string =
    signat ^ "." ^ member ^ "/law-" ^ Int.toString index

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
end
