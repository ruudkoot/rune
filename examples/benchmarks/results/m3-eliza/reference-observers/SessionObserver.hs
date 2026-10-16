module Main where
import Kernel
import System.Environment
main=do
 [arg]<-getArgs
 input<-getContents
 putStr(session initial[](filter(not.null)(map(words.trim)(take(read arg)(lines input)))))
