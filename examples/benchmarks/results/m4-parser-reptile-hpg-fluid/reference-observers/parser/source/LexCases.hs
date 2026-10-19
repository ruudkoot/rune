module LexCases where
import qualified Main as N
import System.Environment(getArgs)
import Control.Exception
import Data.List(isPrefixOf,tails)
endTokens []=[]
endTokens(t@(_,_,w,_):ts)=t:if w==N.Leof then []else endTokens ts
trim xs=case [i|(i,t)<-zip[0..](tails xs),isPrefixOf "CallStack" t]of
 []->xs;i:_->take i xs
observe tokens=do
 let output=show(endTokens tokens)++"\n"
 result<-try(evaluate(length output))::IO(Either SomeException Int)
 return(case result of Right _->"ok\n"++output;Left e->"exception\n"++trim(displayException e))
main=do
 [input,prefix]<-getArgs
 text<-readFile input
 raw<-observe(N.leLex 1 1 text)
 layout<-observe(N.laMain text)
 writeFile(prefix++".raw")raw
 writeFile(prefix++".layout")layout
