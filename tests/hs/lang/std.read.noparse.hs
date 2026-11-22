-- Report 6.3.3: read of no parse fails as error does.
module Main (main) where

main :: IO ()
main = print (read "x" :: Int)
