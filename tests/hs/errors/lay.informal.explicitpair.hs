-- Report 2.7: "The layout rule matches only those open braces that it has inserted; an explicit open brace must be
-- matched by an explicit close brace": `in` closes no brace of the programmer's.
module Main (main) where

main :: IO ()
main = print (let {x = 1
              in x :: Int)
