(* 4.7: ref is no conexp, in parentheses with a type or not, so the binding
   is expansive and the explicit 'a, scoped at the val, cannot be
   generalised (tests/lang/ty.infer.valuerestriction_conexp) *)
val r = (ref : 'a list -> 'a list ref) nil
