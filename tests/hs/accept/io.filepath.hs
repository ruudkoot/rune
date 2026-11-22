-- Report 7.1, 8: FilePath is String: interchangeable in a signature.
module Main (main) where

f :: FilePath -> String
f = id

g :: String -> FilePath
g = f

main :: IO ()
main = return ()
