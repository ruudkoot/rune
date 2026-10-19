module Stages where
import qualified Main as N
import qualified NofibUtils as U
import System.Environment(getArgs)
endTokens []=[]
endTokens(t@(_,_,w,_):ts)=t:if w==N.Leof then []else endTokens ts
main=do
 [input,prefix]<-getArgs
 text<-readFile input
 let raw=endTokens(N.leLex 1 1 text)
     layout=endTokens(N.laMain text)
     result=N.parser_test(N.laMain text)
     output=N.showx result
 writeFile(prefix++".raw")(show raw++"\n")
 writeFile(prefix++".layout")(show layout++"\n")
 writeFile(prefix++".result")output
 writeFile(prefix++".hash")(show(U.hash output)++"\n")
 print(length raw,length layout,length output,U.hash output)
