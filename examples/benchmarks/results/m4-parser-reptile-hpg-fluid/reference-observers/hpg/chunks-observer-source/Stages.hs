module Stages where
import Types
import Env
import GenType
import GenVal
import GenExp
main=gen_types 6 4 8 4 (gen_vals 10 6 (get_all_val_decls (\vds e->do
      writeFile "../initial-values.reference"(concatMap(\x->showsVal_decl x "\n")vds)
      gen_exps 6 (\vnes->get_all_val_decls(\final e->do
       writeFile "../final-values.reference"(concatMap(\x->showsVal_decl x "\n")final)
       writeFile "../expressions.reference"(concatMap(\(n,e)->n++" = "++show e++"\n")vnes)))e)))
      (make_Env(9807,65,32975)default_output)
