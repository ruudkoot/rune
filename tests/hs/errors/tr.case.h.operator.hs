-- Report 3.17.3 (h): a literal pattern needs Eq and Num at its type, so a literal at a function type is refused.
module Main (main) where

f :: (a -> a) -> Int
f 0 = 1

main :: IO ()
main = return ()
