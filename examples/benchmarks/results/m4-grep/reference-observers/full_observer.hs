module Main where
import qualified Kernel as K
import System.Environment
import System.IO
main = do
 [pattern] <- getArgs
 hSetEncoding stdin utf8
 hSetEncoding stdout utf8
 text <- getContents
 let accept=K.acceptor(fst(head(K.nnRegexp pattern)))
 putStr(unlines(filter accept(lines text)))
