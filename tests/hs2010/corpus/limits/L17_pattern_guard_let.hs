-- Report 3.13: pattern guards with let and boolean guards.
module Main where
f :: Int -> String
f n | let m = n * 2, Just k <- lookup m [(4, "four")], not (null k) = k
    | otherwise = "other"
main = putStrLn (f 2 ++ " " ++ f 3)
