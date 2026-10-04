module Main where
import EffBench
import qualified Control.Monad.State.Strict as S
import Control.Exception
import System.Environment
run :: Int -> ((),Int)
run n = frunState (times n (fmodify (+1))) 0
main = do
  args <- getArgs
  let n = read (head args)
  result <- evaluate (run n)
  print result
