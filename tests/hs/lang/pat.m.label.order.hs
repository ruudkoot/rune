-- rows: tr.case.m R16
-- Report 3.17.2, with the erratum of July 2004: labelled fields match in the order the pattern names them, not the
-- declaration's: R {b = False, a = True} against R undefined True fails at b; 3.17.3 (m).
module Main (main) where

data R = R {a, b :: Bool}

main :: IO ()
main = do
  print (case R undefined True of { R {b = False, a = True} -> 1; _ -> 2 :: Int })
  print (case 2 :: Int of { y -> case R undefined True of { R {b = False} -> case R undefined True of { R {a = True} -> 1; _ -> y }; _ -> y } })
