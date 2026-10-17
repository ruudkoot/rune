module Main where
import qualified Typecheck as T
import System.Environment
v=T.F_VAR
lam=T.F_LAMBDA
app=T.F_APE
letE xs es e=T.F_LETE xs es e
letR xs es e=T.F_LETRECE xs es e
tv=T.F_TVAR
con=T.F_TCONS
cases=[("identity",lam "x"(v "x")),("self-application",lam "x"(app(v "x")(v "x"))),
 ("integer-application",app(v "0")(v "1")),("constant",lam "x"(v "1")),
 ("polymorphic-let",letE["id"][lam "x"(v "x")](app(v "id")(v "1"))),
 ("mutual-recursion",letR["f","g"][lam "x"(app(v "g")(v "x")),lam "y"(app(v "f")(v "y"))](v "f"))]
showSub reply=case reply of T.C_FAILURE->"failure";T.F_OK phi->unwords[ T.f_tpr(phi x)|x<-["a","b","c"]]
main=do
 [mode]<-getArgs
 if mode=="rows"then mapM_(\(name,e)->putStrLn(name++" :: "++T.f_check e))T.c_progs
 else if mode=="cases"then mapM_(\(name,e)->putStrLn(name++" "++T.f_check e))cases
 else do
  putStrLn("nodups "++unwords(T.f_nodups["a","b","a","c"]))
  putStrLn("name "++T.f_next_name[2,0,1])
  putStrLn("sequence "++unwords(take 4(T.f_name_sequence[0])))
  putStrLn("compose "++T.f_tpr(T.f_scomp(T.f_delta "b" T.c_tint)(T.f_delta "a"(tv "b"))"a"))
  putStrLn("right-fold "++showSub(T.f_unifyl T.f_id_subst[(tv "a",tv "b"),(tv "a",tv "c")]))
  putStrLn("arity "++showSub(T.f_unify T.f_id_subst(con "pair"[tv "a"],con "pair"[T.c_tint,T.c_tbool])))
  let env=[("x",T.F_SCHEME[](tv "live")),("x",T.F_SCHEME[](tv "hidden"))]
  putStrLn("unknowns "++unwords(T.f_unknowns_te env))
  putStrLn("occurs "++showSub(T.f_unify T.f_id_subst(tv "a",T.f_list(tv "a"))))
  putStrLn("unused-equation "++showSub(T.f_unifyl T.f_id_subst[error "unused equation",(T.c_tint,T.c_tbool)]))
