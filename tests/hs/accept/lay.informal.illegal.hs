-- rows: lay.parseerror.paren lay.parseerror.comma lay.parseerror.bracket
-- Report 2.7: "a close brace is also inserted whenever the syntactic category containing the layout list ends; that is,
-- if an illegal lexeme is encountered at a point where a close brace would be legal": a ), a comma and a ].
module Main (main) where

main :: IO ()
main = do
  print (case x of y -> y)
  print (case x of y -> y, 3 :: Int)
  print [do Just 1, do Nothing]
  print [do Just 2]
  (do return ())
  where x = 1 :: Int
