-- Report 6.3.4: toEnum 7 :: Bool is an error, the Report's example.
module Main (main) where

main :: IO ()
main = print (toEnum 7 :: Bool)
