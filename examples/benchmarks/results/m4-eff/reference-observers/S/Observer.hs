module Main where
import qualified Kernel as K
import qualified Control.Monad.State.Strict as S
import Control.Exception
import System.Environment
run :: Int -> ((),Int)
run n = S.runState (K.times n (S.modify (+1))) 0
main = do
  args <- getArgs
  let n = read (head args)
  result <- evaluate (run n)
  if "force" `elem` args then print result else print (fst result)
