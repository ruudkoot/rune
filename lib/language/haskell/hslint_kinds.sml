(* The kinds of HsLint's second inference (the haskell98 roadmap's M16,
   D54; the Report's 4.6): kinds with variables, their unifier, and the
   kind of a type of the source, which HsLintEnv uses to infer the kinds
   of a dependency group of type constructors and classes, and to check
   every type a program writes. A kind left open when its group is done
   is `*`, for there are no polymorphic kinds in Haskell 98. *)
structure HsLintKinds =
struct
  structure A = HsAst
  structure T = HsLintTypes

  datatype ikind = KStar | KArr of ikind * ikind | KVar of ikind option ref

  fun prune (k as KVar r) = (case !r of SOME k' => let val p = prune k' in r := SOME p; p end | NONE => k)
    | prune k = k

  fun fresh () = KVar (ref NONE)

  fun occurs (r, k) =
    case prune k of
      KVar r' => r = r'
    | KArr (a, b) => occurs (r, a) orelse occurs (r, b)
    | KStar => false

  exception Mismatch

  fun unify (a, b) =
    case (prune a, prune b) of
      (KVar r, KVar r') => if r = r' then () else r := SOME (KVar r')
    | (KVar r, k) => if occurs (r, k) then raise Mismatch else r := SOME k
    | (k, KVar r) => if occurs (r, k) then raise Mismatch else r := SOME k
    | (KStar, KStar) => ()
    | (KArr (a, b), KArr (c, d)) => (unify (a, c); unify (b, d))
    | _ => raise Mismatch

  fun fromKind T.Star = KStar
    | fromKind (T.KFun (a, b)) = KArr (fromKind a, fromKind b)

  (* the kind, with what is open made `*` (4.6) *)
  fun toKind k =
    case prune k of
      KStar => T.Star
    | KArr (a, b) => T.KFun (toKind a, toKind b)
    | KVar r => (r := SOME KStar; T.Star)

  fun show k =
    case prune k of
      KStar => "*"
    | KArr (a as KArr _, b) => "(" ^ show a ^ ") -> " ^ show b
    | KArr (a, b) => show a ^ " -> " ^ show b
    | KVar _ => "k"

  fun tupleKind n = if n = 0 then KStar else KArr (KStar, tupleKind (n - 1))

  (* `infer {con, var} t`: the kind of the type `t`, where `con` gives
     the kind of a constructor by its name and `var` that of a type
     variable. A type applied to what its kind does not take, or an
     argument of the wrong kind, is refused (kind.checked). *)
  fun infer {con : A.qname -> ikind, var : A.name -> ikind} (t as A.T ({span, ...}, x)) : ikind =
    let
      fun fail msg = raise T.Refuse (span, msg)
      fun want (t' as A.T ({span = sp, ...}, _), k) =
        let val k' = infer {con = con, var = var} t'
        in
          unify (k', k)
          handle Mismatch => raise T.Refuse (sp, "a type of kind " ^ show k ^ " is wanted here, and this one has kind " ^
                                                 show k' ^ " (kind.checked)")
        end
    in
      case x of
        A.TVar n => var n
      | A.TCon (A.Name (_, q)) => con q
      | A.TApp (f, a) =>
          let
            val kf = infer {con = con, var = var} f
            val ka = infer {con = con, var = var} a
            val r = fresh ()
          in
            unify (kf, KArr (ka, r))
            handle Mismatch =>
              fail ("a type of kind " ^ show kf ^ " is applied to one of kind " ^ show ka ^ " (kind.checked)");
            r
          end
      | A.TFun (a, b) => (want (a, KStar); want (b, KStar); KStar)
      | A.TList a => (want (a, KStar); KStar)
      | A.TTuple ts => (List.app (fn t' => want (t', KStar)) ts; KStar)
      | A.TParen t' => infer {con = con, var = var} t'
    end
end
