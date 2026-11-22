-- Report 3.14: do is the Monad methods': do at Bool is refused.
module Main (main) where

x :: Bool
x = do { True; False }

main :: IO ()
main = return ()
