module Main where
import qualified Data.Map.Internal as M
import Data.Char
import System.Environment
shape M.Tip="."
shape(M.Bin s(r,c)v l h)="("++unwords[show s,show r,show c,show(ord v),shape l,shape h]++")"
orders name=case name of
 "ascending"->[0..63]
 "descending"->reverse[0..63]
 "zigzag"->concat[[i,63-i]|i<-[0..31]]
 "permuted"->[(i*37)`mod`64|i<-[0..63]]
main=do
 [name]<-getArgs
 let updates=[((i`div`8+1,i`mod`8+1),chr(97+i`mod`14))|i<-orders name]
 mapM_(putStrLn.shape)(tail(scanl(\tree(k,v)->M.insert k v tree)M.empty updates))
