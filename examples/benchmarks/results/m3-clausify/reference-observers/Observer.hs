module Main where
import qualified Kernel as K
import System.Environment
main = do
  [formula] <- getArgs
  putStr(K.clauses formula)
