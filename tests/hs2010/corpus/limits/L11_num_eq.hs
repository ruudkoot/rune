-- Report: Num has Eq and Show superclasses, so Num a gives (==) and show.
module Main where
describe :: Num a => a -> String
describe x = if x == 0 then "zero" else show x
main = putStrLn (describe 0 ++ " " ++ describe (5 :: Int))
