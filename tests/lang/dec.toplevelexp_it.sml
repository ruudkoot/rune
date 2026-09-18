(* exp ; at top level is val it = exp (Appendix A) *)
1 + 2;
val three = it;
"it is rebound";
val () = print (Int.toString three ^ " " ^ it ^ "\n");
