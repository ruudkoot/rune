module Main where
import qualified Kernel as K
import Data.List
import System.Environment
main = do
  [path] <- getArgs
  let allPaths = K.transfer K.initialState K.finalState K.RightBank 0 []
      mins = K.minSolutions allPaths
      counts = [(head xs,length xs) | xs <- group(sort(map K.totalTime allPaths))]
      bits s = [if K.position i s==K.RightBank then 1 else 0 | i <- [K.Bono .. K.Adam]]
  writeFile(path++".histogram") (show counts++"\n")
  writeFile(path++".minimum") (show [[(t,bits s) | (t,s) <- h] | h <- mins]++"\n")
  writeFile(path++".output") (K.writeSolutions mins 1 "")
  print(length allPaths,length mins,map K.totalTime mins)
