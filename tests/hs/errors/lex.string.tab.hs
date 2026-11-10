-- rows: R61
-- Report 2.6: string -> " {graphic<" | \> | space | escape | gap} ": a raw tab is none of these.
module Main (main) where

s :: String
s = "a	b"

main :: IO ()
main = return ()
