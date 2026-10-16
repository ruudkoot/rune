module Main where
import Kernel
import Lisplikefns
import Rewritefns
import System.Environment
sex Nil="()"
sex (Atom s)=s
sex (Cons(a,b))="("++sex a++" . "++sex b++")"
lut Empty=[]
lut (Node(a,(k,rs),b))=lut a++[(k,length rs)]++lut b
main=do
 [arg]<-getArgs
 let i=read arg
 print(lut lemmas)
 putStrLn(sex(teststatement i))
 putStrLn(sex(rewrite(teststatement i)lemmas))
 print(testresult i)
