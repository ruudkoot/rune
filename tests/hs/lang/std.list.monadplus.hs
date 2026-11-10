-- rows: std.maybe.monadplus R22
-- Report 6.1.3, 6.1.8: lists and Maybe are MonadPlus, by the Monad library's class and instances.
module Main (main) where

import Monad

main :: IO ()
main = print (mzero :: [Int], mplus [1] [2 :: Int], mzero :: Maybe Int, mplus Nothing (Just (1 :: Int)))
