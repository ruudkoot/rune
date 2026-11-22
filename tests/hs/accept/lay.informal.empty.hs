-- Report 2.7: "If the indentation of the non-brace lexeme immediately following a where, let, do or of is less than or
-- equal to the current indentation level, then instead of starting a layout, an empty list {} is inserted".
module Main (main) where

class C a where
instance C Int where

main :: IO ()
main = return ()
