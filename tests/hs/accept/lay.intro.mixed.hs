-- rows: lay.informal.explicitoff
-- Report 2.7: "layout-sensitive and layout-insensitive styles of coding can be freely mixed within one program", and
-- "Within explicit open braces, no layout processing is performed for constructs outside the braces, even if a
-- line is indented to the left of an earlier implicit open brace."
module Main (main) where

main :: IO ()
main = do
  let { a = 1
; b = 2
}
  print (a + b :: Int)
  print (h 2)
  where h x = case x of { 1 -> 0; _ -> let y = x
                                         in y * 2 :: Int }
