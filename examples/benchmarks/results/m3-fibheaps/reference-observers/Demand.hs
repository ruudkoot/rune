module Main where
import qualified Kernel as K
import Control.Exception
heap :: K.FibHeap Int
heap=K.FH 2 (0,K.Node 0 []) (error "unneeded forest")
main = do
  _ <- evaluate(K.deleteMinFH' heap)
  putStrLn "functional header deferred"
  mutable <- try(evaluate(K.deleteMinFH heap)) :: IO(Either SomeException(K.FibHeap Int))
  case mutable of Left _ -> putStrLn "mutable header demanded"; Right _ -> error "unexpected mutable success"
  minimum <- try(evaluate(K.minFH(K.deleteMinFH' heap))) :: IO(Either SomeException Int)
  case minimum of Left _ -> putStrLn "functional minimum demanded"; Right _ -> error "unexpected minimum success"
