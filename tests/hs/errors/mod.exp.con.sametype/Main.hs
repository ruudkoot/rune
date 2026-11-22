-- Report 5.2: T in an export list names the type, even where a constructor is called T too.
module Main (main) where

import M

main :: IO ()
main = case T of _ -> return ()
