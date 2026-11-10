-- rows: tr.case.h tr.case.h.strings pat.ex.list.fail R14
-- Report 3.17.2: a string literal pattern compares by == on [Char]: "ab" against 'x':undefined fails; ['a','b'] against
-- ['x',bottom] fails; 3.17.3 (h): case v of { k -> e; _ -> e' } is if v == k then e else e'.
module Main (main) where

s :: String -> Int
s "ab" = 1
s _ = 2

l :: String -> Int
l ['a', 'b'] = 1
l _ = 2

main :: IO ()
main = do
  print (s ('x' : undefined), l ('x' : undefined), l ['x', undefined])
  print (s "ab", if "ab" == "ab" then 1 else 2 :: Int)
  print (case 3 :: Int of { 3 -> "three"; _ -> "no" }, if (3 :: Int) == 3 then "three" else "no")
  print (case 'c' of { 'c' -> 1; _ -> 2 :: Int })
