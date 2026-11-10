-- Report 4.2.3: a newtype's field selector unwraps: unAge (Age 3) is 3, and unAge bottom is bottom.
module Main (main) where

newtype Age = Age { unAge :: Int }

main :: IO ()
main = do
  print (unAge (Age 3))
  print (seq (unAge undefined) (1 :: Int))
