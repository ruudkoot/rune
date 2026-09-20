(* The library through the compiler's elaborator (docs/plans/docgen.md, D7,
   D12). Extraction works on syntax; what only the static semantics knows is
   asked here: whether a structure matches the signature it claims to
   implement. The library is elaborated as the compiler's driver elaborates
   it, every file of the MANIFEST in order with the fixity threaded through,
   and a claim `Implements: SIG where type ...` of a structure S is checked by
   elaborating `structure Claim : SIG where type ... = S` on top of that: what
   the compiler says against it is the diagnostic. *)
structure DocElab =
struct
  type library = {env : Env.env, fixity : Fixity.env}

  (* NONE when the library does not elaborate; the compiler's error is
     reported, and the documentation is still made. *)
  fun library (dir : string) : library option =
    let
      val fixity = ref Fixity.initial
      fun parse (e : BasisManifest.entry) =
        let val (prog, fx) = Parser.parseTokensWith (Lexer.tokenize (Source.load (dir ^ "/" ^ #file e)), !fixity)
        in fixity := fx; prog end
      val prog = List.concat (List.map parse (BasisManifest.readManifest dir))
      val env = ref Env.initial
    in
      Elaborate.allowPrim := true;
      Elaborate.elabTop (env, prog);
      Elaborate.finish ();
      Error.warnings := [];
      SOME {env = !env, fixity = !fixity}
    end
    handle Error.CompileError (sp, msg) =>
      (DocDiag.error (sp, "the library does not elaborate, so that no claim is checked: " ^ msg); NONE)

  (* How many arguments a value of this type takes one after another, with
     type abbreviations expanded, as elaboration has done. *)
  fun arrows (ty : Types.ty) : int =
    case ty of
      Types.TArrow (_, result) => 1 + arrows result
    | Types.TVar (ref (Types.Bound t)) => arrows t
    | _ => 0

  (* The usage head of a value of a signature against its elaborated type:
     extraction let a head have more arguments than the written type shows
     arrows where the result might abbreviate a function type; now we know. *)
  fun checkHead (signat : string, name : string, head : DocHead.head, span : Source.span) : unit =
    case StringMap.find (!Elaborate.sigs, signat) of
      SOME {env = Env.Env {vals, ...}, ...} =>
        (case StringMap.find (vals, name) of
           SOME (Env.Val {scheme, ...}) =>
             if #arity head > arrows scheme then
               DocDiag.error (span, "the usage `" ^ #code head ^ "` has " ^ Int.toString (#arity head)
                                    ^ " arguments, and " ^ name ^ " takes " ^ Int.toString (arrows scheme)
                                    ^ ": its type is " ^ Types.toString scheme)
             else ()
         | _ => ())
    | NONE => ()

  (* A structure against the signature it claims. *)
  fun checkClaim ({env, fixity} : library) (c : DocClaims.claim) : unit =
    if #isFunctor c then ()
    else
      let
        val text = "structure DocgenClaim : " ^ #signat c
                   ^ (if #realisations c = "" then "" else " " ^ #realisations c) ^ " = " ^ #name c
        val (prog, _) = Parser.parseTokensWith (Lexer.tokenize (Source.fromString ("<claim>", text)), fixity)
      in
        Elaborate.elabTop (ref env, prog);
        Elaborate.finish ();
        Error.warnings := []
      end
      handle Error.CompileError (_, msg) =>
        DocDiag.error (#span c, #name c ^ " does not implement " ^ #signat c
                                ^ (if #realisations c = "" then "" else " " ^ #realisations c)
                                ^ ", as its comment claims: " ^ msg)
end
