module Main where
import GamtebMain
import InitTable
import Output
import Data.Array
import System.Environment
main=do
 [size,out]<-getArgs
 let n=read size
 let (results,stats)=sources 0.5 n 6
 let text=outGamteb n stats results
 if text/=gamteb n then error "observer differs" else return()
 writeFile(out++".text")text
 writeFile(out++".results")(unlines[unwords[show i,show j,show w]|((i,j),w)<-results])
 writeFile(out++".stats")(unlines[unwords[show i,show value]|(i,value)<-stats])
 putStrLn(unwords["particles",show n,"results",show(length results),"stats",show(length stats)])
