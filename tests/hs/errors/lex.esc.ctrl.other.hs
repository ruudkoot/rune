-- Report 2.6: cntrl -> ascLarge | @ | [ | \ | ] | ^ | _ and nothing else: `\^a` is none.
module Main (main) where

c :: Char
c = '\^a'

main :: IO ()
main = return ()
