(* a clause of a chain of where's sees what the clauses before it defined *)
signature S = sig type t type u end where type t = int and type u = string where type t = bool
