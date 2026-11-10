-- Report 2.4: "An operator symbol starting with any other character [than a colon] is an ordinary identifier": `+:`
-- is no constructor in a pattern.
module Main (main) where

f :: Int -> Int
f (a +: b) = a

main :: IO ()
main = return ()
