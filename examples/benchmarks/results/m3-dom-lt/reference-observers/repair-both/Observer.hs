module Main where
import Dom
import System.Environment
main = do
 [path]<-getArgs
 contents<-readFile path
 mapM_ (print . idom . (\(root,adj)->(root,fromAdj adj)) . read) (lines contents)
