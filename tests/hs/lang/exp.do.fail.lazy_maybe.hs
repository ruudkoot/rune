-- Report 3.14: a refutable pattern of do is matched strictly: True <- return undefined diverges at Maybe.
module Main (main) where

main :: IO ()
main = print (do { True <- return undefined; return 1 } :: Maybe Int)
