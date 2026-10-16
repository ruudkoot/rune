module Main where
import RichProg
import Auxil
import qualified Key
main=do
 print Key.keys
 print freqtab
 print maxval
 print [(s,a,z,n) | K s a z n <- blocked (attribkeys Key.keys)]
 mapM_ (\n->putStrLn(prog n)) [1,2]
 mapM_ (\n->putStrLn(show n ++ ":" ++ show(findhash(blocked(attribkeys(take n Key.keys)))))) [0,1,2,5,10,15,22]
