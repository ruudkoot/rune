module Main where
import qualified Kernel as K
import System.Environment
main = do
 [path] <- getArgs
 text <- readFile path
 putStr (if null text then [] else K.fmt text)
