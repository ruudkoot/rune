module Main where
import qualified Kernel as K
import Control.Exception
main = do
 let output=K.readAt (1,1) 3 (\_ -> error "EOF callback") "X"
 print(take 1 output)
 result<-try(evaluate(length output)) :: IO(Either SomeException Int)
 case result of Left _ -> putStrLn "PASS EOF callback demanded only after prefix"
                Right _ -> error "missing callback demand"
