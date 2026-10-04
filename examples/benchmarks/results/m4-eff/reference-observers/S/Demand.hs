module Main where
import qualified Kernel as K
import qualified Control.Monad.State.Strict as S
import Control.Exception
main = do
  result <- evaluate (S.runState (K.times 5 (S.modify (\_ -> error "unneeded state"))) (0::Int))
  print (fst result)
  forced <- try (evaluate (snd result)) :: IO (Either SomeException Int)
  case forced of Left _ -> putStrLn "counter failure deferred"; Right _ -> error "counter unexpectedly succeeds"
