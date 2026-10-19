module ObserveCases where
import qualified Main as V
import Core_datatype
import Goals
import Tree
import Type_defs
import Vtslib
import Edlib
import Unparse
import ObserveProtocol(hex)
import System.IO(openBinaryFile,IOMode(ReadMode),hGetContents)
import Control.Exception(try,evaluate,SomeException)
import System.Timeout(timeout)
import Data.List(intercalate)
readBytes path=do h<-openBinaryFile path ReadMode;hGetContents h
proof(TreeSt(Tree(Goal _ _ _ uid object _ sg _) children done _ _) _ _)=
 let r=case done of { NONE->"none"; SOME(ThmDone theorem)->"proof:"++hex(unparse_th theorem); SOME _->"other" }
 in uid++":"++show(length children)++":"++r
main=do
 names<-fmap lines(readFile"../cases/FILES")
 mapM_(\name->do
   input<-readBytes("../cases/"++name++".input")
   observed<-try(timeout 2000000(evaluate(length(V.main' input))))::IO(Either SomeException(Maybe Int))
   case observed of
     Left err->writeFile("../cases/"++name++".exception")(show err)
     Right Nothing->writeFile("../cases/"++name++".exception")"original timed out"
     Right(Just n)->do
       writeFile("../cases/"++name++".protocol")(hex(V.main' input))
       let (_,result,_)=V.proof_edit "" [] (input,[0..],[1..])
           status=case result of Bad message->"bad="++hex message;Ok state->proof state
       result<-try(evaluate(length status))::IO(Either SomeException Int)
       case result of Left err->writeFile("../cases/"++name++".proof-exception")(show err)
                      Right _->writeFile("../cases/"++name++".proof")status
       print(name,n))
  names
