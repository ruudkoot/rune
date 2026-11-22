-- Report 5.2: a constructor not listed is not exported.
module Main (main) where

import M

main :: IO ()
main = case E of _ -> return ()
