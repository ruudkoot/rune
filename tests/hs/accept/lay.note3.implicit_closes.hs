-- rows: R2 deviation
-- Report 9.3, Note 3 says "A parse error results if an explicit close brace matches an implicit open brace", and 2.7 says
-- a close brace is inserted where an illegal lexeme meets a legal close: they disagree (R2), and rhc takes 2.7
-- (D38, on the ground that the two contradict): the } below closes the case's implicit block.
module Main (main) where

main :: IO ()
main = let { x = case 1 of y -> y } in print (x :: Int)
