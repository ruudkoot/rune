-- Report 2.2: uniLarge -> any uppercase or titlecase Unicode letter: the titlecase U+01C5 begins a conid.
module Main (main) where

data T = ǅ Int

main :: IO ()
main = case ǅ 1 of ǅ n -> print n
