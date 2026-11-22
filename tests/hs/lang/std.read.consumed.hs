-- Report 6.3.3: read wants the whole string consumed, but for white space: read "1 x" :: Int fails.
module Main (main) where

main :: IO ()
main = print (read "1 x" :: Int)
