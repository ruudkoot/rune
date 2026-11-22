-- Report 3.16: a signature disambiguates: show (read s :: Int).
module Main (main) where

f :: String -> String
f s = show (read s :: Int)

main :: IO ()
main = return ()
