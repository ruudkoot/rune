-- rows: pat.ref.def
-- Report 3.17.2: sub-patterns match left to right: the first diverging makes the match diverge, a failure after it unseen.
module Main (main) where

data C = C Bool Bool

main :: IO ()
main = print (case C undefined False of { C True True -> 1; _ -> 2 :: Int })
