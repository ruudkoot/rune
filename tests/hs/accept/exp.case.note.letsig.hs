-- rows: R65
-- Report 3.13, the note: case x of { (a,_) | let b = not a in b :: Bool -> a } has the single parse
-- case x of { (a,_) | (let b = not a in b :: Bool) -> a }, which limited lookahead must not refuse.
module Main (main) where

main :: IO ()
main = print (case (True, ()) of { (a,_) | let b = not a in b :: Bool -> a ; _ -> False })
