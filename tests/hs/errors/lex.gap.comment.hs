-- Report 2.6: gap -> \ whitechar {whitechar} \: white characters only, so no comment.
module Main (main) where

s :: String
s = "a\ -- a comment
     \b"

main :: IO ()
main = return ()
