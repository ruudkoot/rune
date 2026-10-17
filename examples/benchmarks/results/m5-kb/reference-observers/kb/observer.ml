open Kernel
let rec term = function
 | Var v -> "v" ^ string_of_int v
 | Term(name,sons) -> name ^ "(" ^ String.concat "," (List.map term sons) ^ ")"
let () =
 let n=check_rules [] in
 let eqs=List.map(fun rule->rule.lhs,rule.rhs)geom_rules in
 let result=kb_completion greater n [] [] (n,n) eqs in
 pretty_rules(List.rev result);
 List.iter(fun rule->Printf.printf "%d %d %s=%s\n" rule.number rule.numvars (term rule.lhs)(term rule.rhs))result
