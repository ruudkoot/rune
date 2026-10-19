module ParseCases where
import qualified Main as N
import System.Environment(getArgs)
import Control.Exception
import Data.List(isPrefixOf,tails)
trim xs=case [i|(i,t)<-zip[0..](tails xs),isPrefixOf "CallStack" t]of []->xs;i:_->take i xs
dump r=case r of
 N.PFail t->"fail "++show t++"\n"
 N.POk env toks value->"ok "++show env++" "++show(head(toks++[N.pgEOF]))++" "++show value++"\n"
main=do
 [mode,input,output]<-getArgs
 text<-readFile input
 let tokens=N.laMain text
     env=N.hsPrecTable
     result=case mode of
      "module"->dump(N.paModule env tokens)
      "expr"->dump(N.paExpr env tokens)
      "pat"->dump(N.paPat env tokens)
      "type"->dump(N.paType env tokens)
      "valdef"->dump(N.paValdef env tokens)
      "data"->dump(N.paDataDecl env tokens)
      _->error"mode"
 forced<-try(evaluate(length result))::IO(Either SomeException Int)
 writeFile output(case forced of Right _->result;Left e->"exception "++trim(displayException e))
