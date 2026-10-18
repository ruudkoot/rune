module Main where
import CacheMain (doFile)
import System.Environment
main=do {args<-getArgs; input<-getContents; out<-doFile (read(head args)) [] input; putStr out}
