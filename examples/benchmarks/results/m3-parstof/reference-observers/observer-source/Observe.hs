{-# LANGUAGE ScopedTypeVariables #-}
module Main where
import Kernel
import Data.Data
import Data.Char (ord)
import System.Environment
quote s="\""++concatMap esc s++"\"" where
 esc '"'="\\\""
 esc '\\'="\\\\"
 esc '\n'="\\n"
 esc '\r'="\\r"
 esc '\t'="\\t"
 esc c=[c]
dump :: Data a=>a->String
dump x=case cast x of
 Just(n::Int)->show n
 Nothing->case cast x of
  Just(c::Char)->show(ord c)
  Nothing->case cast x of
   Just(s::String)->quote s
   Nothing->"["++quote(showConstr(toConstr x))++concatMap(","++)(gmapQ dump x)++"]"
main=do
 [mode,path]<-getArgs
 txt<-readFile path
 case mode of
  "errors"->mapM_ (\(a,b)->putStrLn(a++"\t"++quote b)) [("c_err_comment",c_err_comment),("c_err_lexical",c_err_lexical),("c_err_CASE",c_err_CASE),("c_err_CASEpatt",c_err_CASEpatt),("c_err_ELSE",c_err_ELSE),("c_err_FI",c_err_FI),("c_err_THEN",c_err_THEN),("c_err_THENELIF",c_err_THENELIF),("c_err_cbrack",c_err_cbrack),("c_err_closbr",c_err_closbr),("c_err_constr",c_err_constr),("c_err_endCASE",c_err_endCASE),("c_err_endtup",c_err_endtup),("c_err_endtupl",c_err_endtupl),("c_err_enduni",c_err_enduni),("c_err_explist",c_err_explist),("c_err_funcdef",c_err_funcdef),("c_err_funtyp",c_err_funtyp),("c_err_funtype",c_err_funtype),("c_err_letlist",c_err_letlist),("c_err_nest",c_err_nest),("c_err_nesttype",c_err_nesttype),("c_err_progterm",c_err_progterm),("c_err_rhsop",c_err_rhsop),("c_err_rhstype",c_err_rhstype),("c_err_rhsunop",c_err_rhsunop),("c_err_semicol",c_err_semicol),("c_err_tuptype",c_err_tuptype),("c_err_typedef",c_err_typedef),("c_err_unitype",c_err_unitype)]
  "program"->putStr(c_the_program 1)
  "tokens"->putStrLn(dump(f_tokenize txt))
  "parse"->putStrLn(dump(c_par_proglist(f_tokenize txt)))
