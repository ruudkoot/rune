-- rows: pat.m.data.succeed pat.m.data.first pat.m.data.other tr.case.p pat.m.label.same pat.m.label.unnamed tr.case.n tr.case.o
-- Report 3.17.2: a constructor's sub-patterns match left to right, the first to fail making the match fail; another
-- constructor fails without forcing fields; labelled fields match in the order the pattern names them (erratum
-- of July 2004), the others as _; 3.17.3 (m), (n), (o), (p).
module Main (main) where

data C = C Bool Bool
data R = R {a, b :: Bool}

main :: IO ()
main = do
  print (case C False undefined of { C True False -> 1; _ -> 2 :: Int })
  print (case C True False of { C True False -> 1; _ -> 2 :: Int })
  print (case Nothing :: Maybe Int of { Just _ -> 1; _ -> 2 :: Int }, case Left undefined :: Either Int Int of { Right _ -> 1; _ -> 2 :: Int })
  print (case R True False of { R {a = True} -> 1; _ -> 2 :: Int }, case R True False of { R True _ -> 1; _ -> 2 :: Int })
  print (case R undefined True of { R {b = True} -> 1; _ -> 2 :: Int })
  print (case R undefined True of { R {} -> 1 :: Int }, case R undefined True of { R _ _ -> 1 :: Int })
