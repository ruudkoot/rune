module Main where
import Circuit
import System.Environment
main = do
 [mode,w,c] <- getArgs
 let width=read w; cycles=read c; inputs=[(2+3*i,11+2*i) | i<-[1..]]
 putStr (if mode=="trace" then traceMult 10 width cycles inputs else runMult width cycles inputs)
