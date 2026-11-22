-- Report 2.2: large -> ascLarge | uniLarge; uniLarge -> any uppercase or titlecase Unicode letter: Δ begins a conid.
module Main (main) where

data T = Δ Int

main :: IO ()
main = case Δ 1 of Δ n -> print n
