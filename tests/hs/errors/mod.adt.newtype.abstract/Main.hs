-- Report 5.8: nor through the newtype's.
module Main (main) where

import NStack

main :: IO ()
main = case Stk [] of _ -> return ()
