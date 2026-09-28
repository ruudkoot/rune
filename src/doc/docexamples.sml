(* Examples that run (docs/plans/docgen.md, D10; docs/plans/quickcheck.md,
   M1). Every piece of code in an `Example:` paragraph is a claim: a closed
   expression of type bool that is true. Each is elaborated when the
   documentation is made, so that one that is no Standard ML, not of type
   bool, or names what is not there, is an error at its comment; and the
   examples of a signature are written out as a program that tries each,
   which the test suite runs.

   The names of the signature's members are in scope, as they are inside a
   structure that implements it: the example is read under `open S`, where S
   is the structure with the shortest name among those that implement the
   signature (`Int` for `INTEGER`), and under `open S.Sub` as well for a
   member of a substructure. Another structure is named in full. *)
structure DocExamples =
struct
  structure I = DocIR
  structure T = DocText

  type example = {signat : string,
                  member : string,              (* with its substructures; "" for the signature itself *)
                  path : string list,           (* the substructures *)
                  code : string, span : Source.span,
                  counter : bool}               (* a `Counterexample:`, a claim that must not hold *)

  fun ofDoc (signat, member, path, span) (doc : I.doc) : example list =
    let
      fun pieces (counter, body) =
        List.mapPartial (fn T.Code c => SOME {signat = signat, member = member, path = path, code = c, span = span,
                                              counter = counter}
                          | _ => NONE) body
    in
      List.concat
        (List.map (fn T.Reserved {keyword = "Example", body, ...} => pieces (false, body)
                    | T.Reserved {keyword = "Counterexample", body, ...} => pieces (true, body)
                    | _ => [])
                  doc)
    end

  fun ofSignature (s : I.signatureRecord) : example list =
    ofDoc (#name s, "", [], #span s) (#doc s)
    @ List.concat (List.map (fn e : I.entryRecord =>
                               ofDoc (#name s, String.concatWith "." (#path e @ [#name e]), #path e, #span e) (#doc e))
                            (DocPage.entriesOf (#body s)))

  (* The structure whose members an example of the signature names: of those
     that implement it the one with the shortest name, and the first in the
     alphabet of several, among those the specification requires if there are
     any. So it is Int for INTEGER and not Int8 or LargeInt. *)
  fun structureOf (claims : DocClaims.claim list, statusOf : DocClaims.claim -> string) (signat : string) : string option =
    let
      val mine = List.filter (fn c : DocClaims.claim => #signat c = signat andalso not (#isFunctor c) andalso #origin c <> "inherited")
                             claims
      val required = List.filter (fn c => statusOf c = "required") mine
      fun better (a : string, b : string) =
        String.size a < String.size b orelse (String.size a = String.size b andalso a < b)
      fun best [] = NONE
        | best (c :: cs) = SOME (List.foldl (fn (x : DocClaims.claim, b) => if better (#name x, b) then #name x else b) (#name c) cs)
    in
      best (if List.null required then mine else required)
    end

  (* The example as an expression of type bool. *)
  fun expression (structure' : string option, {path, code, ...} : example) : string =
    case structure' of
      NONE => code
    | SOME s =>
        let
          fun prefixes ([], _) = []
            | prefixes (p :: ps, sofar) = (sofar ^ "." ^ p) :: prefixes (ps, sofar ^ "." ^ p)
        in
          "let open " ^ String.concatWith " " (s :: prefixes (path, s)) ^ " in " ^ code ^ " end"
        end

  fun nameOf ({signat, member, code, counter, ...} : example) : string =
    signat ^ (if member = "" then "" else "." ^ member) ^ ": " ^ (if counter then "counterexample " else "") ^ code

  (* The code under the structure's names, as `expression` reads an example. *)
  fun opened (structure' : string option, e : example) (code : string) : string =
    expression (structure', {signat = #signat e, member = #member e, path = #path e, code = code, span = #span e,
                             counter = #counter e})

  (* A counterexample as what the program tries: the outcomes of an
     equation's two sides, which must differ, or a claim that must be false
     or raise. The top-level fixity splits the equation, as a law's is. *)
  fun counterClaim (structure' : string option, e : example) : string =
    case DocElab.sides Fixity.initial (#code e) of
      SOME (l, r) => "differ (fn () => " ^ opened (structure', e) l ^ ", fn () => " ^ opened (structure', e) r ^ ")"
    | NONE => "not (" ^ expression (structure', e) ^ ")"

  (* What elaborating a counterexample checks, as a `bool`: an equation's
     sides have one type that admits equality, which the program compares
     their values at. *)
  fun counterCheck (structure' : string option, e : example) : string =
    case DocElab.sides Fixity.initial (#code e) of
      SOME (l, r) => "let fun differ (l : unit -> ''a, r : unit -> ''a) = true in differ (fn () => "
                     ^ opened (structure', e) l ^ ", fn () => " ^ opened (structure', e) r ^ ") end"
    | NONE => expression (structure', e)

  (* The program that tries the examples of one signature: a line PASS or
     FAIL for each, and a status that says whether all hold. An example that
     raises an exception does not hold. *)
  fun program (signat : string, file : string, structure' : string option, examples : example list) : string =
    "(* The examples of the documentation of " ^ signat ^ ", as a program.\n"
    ^ "   Generated by runedoc from " ^ file ^ "; do not edit. *)\n"
    ^ "val failed = ref 0\n"
    ^ "fun example (name, holds) =\n"
    ^ "  if holds () handle _ => false then print (\"PASS \" ^ name ^ \"\\n\")\n"
    ^ "  else (print (\"FAIL \" ^ name ^ \"\\n\"); failed := !failed + 1)\n"
    ^ (if List.exists #counter examples then
         "(* a counterexample holds when its claim does not: the outcomes of an\n"
         ^ "   equation's sides differ, or a claim is false or raises *)\n"
         ^ "datatype 'a outcome = Value of 'a | Raised of string\n"
         ^ "fun outcome f = Value (f ()) handle e => Raised (exnName e)\n"
         ^ "fun differ (l, r) =\n"
         ^ "  case (outcome l, outcome r) of\n"
         ^ "    (Value a, Value b) => a <> b\n"
         ^ "  | (Raised m, Raised n) => m <> n\n"
         ^ "  | _ => true\n"
         ^ "fun counterexample (name, fails) = example (name, fn () => fails () handle _ => true)\n"
       else "")
    ^ String.concat (List.map (fn e =>
                                 if #counter e then
                                   "val () = counterexample (\"" ^ String.toString (nameOf e) ^ "\",\n"
                                   ^ "  fn () => " ^ counterClaim (structure', e) ^ ")\n"
                                 else
                                   "val () = example (\"" ^ String.toString (nameOf e) ^ "\",\n"
                                   ^ "  fn () => " ^ expression (structure', e) ^ ")\n")
                              examples)
    ^ "val () = if !failed = 0 then () else OS.Process.exit OS.Process.failure\n"
end
