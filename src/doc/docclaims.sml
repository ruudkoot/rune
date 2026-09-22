(* What implements what (docs/plans/docgen.md, D7). Most structures of a
   library are not ascribed their signature in the source, so a structure says
   what it implements in the comment that documents it:

       Implements: INTEGER where type int = int

   An ascription in the source counts as a claim as well. A claim is checked
   by name here (the signature must be documented) and by the compiler from
   M8 on. Claims give the signature pages their list of implementations, send
   `List.map` to the page of LIST, and are written to claims.tsv, which a
   script of the test suite compares with the structures that the suite
   matches against the specification's signatures. *)
structure DocClaims =
struct
  structure I = DocIR
  structure T = DocText

  type claim = {name : string,               (* the structure or functor, with the structures it is inside: OS.Path *)
                isFunctor : bool,
                signat : string,
                realisations : string,       (* the rest of the signature expression: where type ... *)
                opaque : bool,
                status : string option,      (* of the structure itself; NONE: that of its signature *)
                summary : T.inline list,     (* the first paragraph of its comment *)
                origin : string,             (* claimed (Implements:), ascribed (in the source), or inherited
                                                (a substructure of the structure that this one is bound to) *)
                file : string, span : Source.span}

  fun reserved (doc : I.doc, keyword : string) : T.inline list list =
    List.mapPartial (fn T.Reserved {keyword = k, body, ...} => if k = keyword then SOME body else NONE | _ => NONE) doc

  (* "SIG where type ..." as the signature and the rest *)
  fun split (sigexp : string) : (string * string) option =
    let
      val s = T.oneLine sigexp
      fun isName c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'"
      fun stop i = if i < String.size s andalso isName (String.sub (s, i)) then stop (i + 1) else i
      val n = stop 0
    in
      (* `sig ... end` written out is no name: there is nothing to link to *)
      if n = 0 orelse String.substring (s, 0, n) = "sig" then NONE
      else SOME (String.substring (s, 0, n), T.oneLine (String.extract (s, n, NONE)))
    end

  fun summaryOf (doc : I.doc) : T.inline list =
    case List.find (fn T.Para _ => true | _ => false) doc of SOME (T.Para is) => is | _ => []

  fun statusOf (doc : I.doc) : string option =
    case reserved (doc, "Status") of body :: _ => SOME (T.plain body) | [] => NONE

  (* The claims of a documented thing: its `Implements:` paragraphs, and its
     ascription unless a paragraph claims the same signature (the paragraph
     has the realisations, which a transparent ascription need not write). *)
  fun claimsOf (name, isFunctor, doc : I.doc, ascription : I.ascription option, file, span) : claim list =
    let
      fun make (sigexp, opaque, origin) =
        case split sigexp of
          SOME (signat, realisations) =>
            SOME {name = name, isFunctor = isFunctor, signat = signat, realisations = realisations, opaque = opaque,
                  status = statusOf doc, summary = summaryOf doc, origin = origin, file = file, span = span}
        | NONE => (DocDiag.error (span, "`Implements:` names a signature, as in `Implements: INTEGER where type int = int`"); NONE)
      val opaque = case ascription of SOME {opaque, ...} => opaque | NONE => false
      val written = List.mapPartial (fn body => make (T.plain body, opaque, "claimed")) (reserved (doc, "Implements"))
      val ascribed =
        case ascription of
          SOME {sigexp, opaque} =>
            (case split sigexp of
               SOME (s, _) => if List.exists (fn c : claim => #signat c = s) written then [] else Option.getOpt (Option.map (fn c => [c]) (make (sigexp, opaque, "ascribed")), [])
             | NONE => [])     (* sig ... end: nothing to link to *)
        | NONE => []
    in
      written @ ascribed
    end

  (* The claims of a module and of the structures inside it, under their
     public path. A structure that is bound to another one by name
     (`structure FileSys = RunePosixFileSys` inside Posix) has the
     substructures of that one: Posix.FileSys.S is RunePosixFileSys.S. *)
  fun ofModule (tops : I.module list) (prefix : string) (m : I.module) : claim list =
    case m of
      I.Struct {name, doc, ascription, subs, rhs, file, span, ...} =>
        let
          (* inherited: the structure it is bound to is public itself, so
             that its substructures have a path of their own already *)
          val (inner, inherited) =
            case rhs of
              I.Alias target =>
                (case List.find (fn I.Struct {name = n, ...} => n = target | _ => false) tops of
                   SOME (I.Struct {subs = subs', ...}) => (subs', not (String.isPrefix "Rune" target))
                 | _ => (subs, false))
            | _ => (subs, false)
          fun mark (c : claim) : claim =
            if not inherited then c
            else {name = #name c, isFunctor = #isFunctor c, signat = #signat c, realisations = #realisations c,
                  opaque = #opaque c, status = #status c, summary = #summary c, origin = "inherited",
                  file = #file c, span = #span c}
        in
          claimsOf (prefix ^ name, false, doc, ascription, file, span)
          @ List.map mark (List.concat (List.map (ofModule tops (prefix ^ name ^ ".")) inner))
        end
    | I.Functor {name, doc, result, file, span, ...} => claimsOf (name, true, doc, result, file, span)
    | I.Signature _ => []
    | I.Decl _ => []

  (* The claims of the public modules: those whose name, and the names of the
     structures they are inside, do not begin with Rune. *)
  fun ofModules (isPublic : string -> bool) (modules : I.module list) : claim list =
    List.filter (fn c : claim => List.all isPublic (String.fields (fn ch => ch = #".") (#name c)))
                (List.concat (List.map (ofModule modules "") modules))

  (* A claim names a signature that is documented. *)
  fun checkNames (signatures : I.module StringMap.map) (claims : claim list) : unit =
    List.app (fn c : claim =>
                if StringMap.member (signatures, #signat c) then ()
                else DocDiag.error (#span c, #name c ^ " claims to implement " ^ #signat c ^ ", which is no signature of the library"))
             claims

  (* claims.tsv: name, kind, signature, realisations, status, origin, source. *)
  (* The signatures come first, so that a reader of the file sees what the
     library declares before what implements it; a signature has no signature
     of its own and no realisations, and its origin is where it is declared. *)
  fun tsv (claims : claim list, statusOfSignature : string -> string,
           signatures : (string * string) list) : string =
    String.concat
      ("name\tkind\tsignature\trealisations\tstatus\torigin\tsource\n"
       :: List.map (fn (name, file) =>
                      String.concatWith "\t"
                        [name, "signature", "", "", statusOfSignature name, "declared", file] ^ "\n")
                   signatures
       @ List.map (fn c : claim =>
                      String.concatWith "\t"
                        [#name c, if #isFunctor c then "functor" else "structure", #signat c, #realisations c,
                         (case #status c of SOME s => s | NONE => statusOfSignature (#signat c)), #origin c, #file c] ^ "\n")
                   claims)
end
