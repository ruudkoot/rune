module Main where
import Kernel
import Data.List(intercalate)
arr xs="["++intercalate "," xs++"]"
def (F_Def name args body)=arr[show name,arr(map show args),expr body]
expr value=case value of
 F_Apl name args->arr[show "Apl",show name,arr(map expr args)]
 F_Cmp body qs->arr[show "Cmp",expr body,arr(map qual qs)]
 F_Let ds body->arr[show "Let",arr(map def ds),expr body]
 F_Cns name->arr[show "Cns",show name]
 F_Var name->arr[show "Var",show name]
qual value=case value of
 F_Gen n name body->arr[show "Gen",show n,show name,expr body]
 F_Fil body->arr[show "Fil",expr body]
main=putStrLn(arr(map def (f_tp c_prg)))
