module Demand where
import qualified Main as N
isOk(N.POk _ _ _)=True
isOk _=False
isFail(N.PFail _)=True
isFail _=False
failParser _ _=N.PFail N.pgEOF
mustSkip _ _=error"unexpected demand"
token line=(line,error"column",N.Lvar,"")
main=do
 print(isOk(N.pgAlts[N.pgEmpty(42::Int),mustSkip]N.hsPrecTable(error"tokens")))
 print(isFail(N.pgThen2(\_ _->error"join")failParser mustSkip N.hsPrecTable(error"tokens")))
 print(isFail(N.pgGetLineNumber failParser N.hsPrecTable(error"tokens")))
 let N.PFail(l,_,_,_)=N.pgAlts[\_ _->N.PFail(token 10),\_ _->N.PFail(token 20)]N.hsPrecTable[token 0]
 print(l==20)
