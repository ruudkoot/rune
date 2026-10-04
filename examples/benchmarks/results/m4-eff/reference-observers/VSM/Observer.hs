module Main where
import EffBench
import Control.Exception
import System.Environment
run :: Int -> ((),Int)
run n = vmrunState (times n (vmmodify (+1))) 0
main = do
  args <- getArgs
  result <- evaluate (run (read (head args)))
  print result
