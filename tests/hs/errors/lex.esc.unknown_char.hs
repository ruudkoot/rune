-- Report 2.6: charesc -> a | b | f | n | r | t | v | \ | " | ' | &, and no other: `\q` is none.
module Main (main) where

c :: Char
c = '\q'

main :: IO ()
main = return ()
