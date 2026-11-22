-- Report 5.3.1: and T alone names the type, leaving out a constructor named T.
module Main (main) where

import MT (T)

main :: IO ()
main = case T of _ -> return ()
