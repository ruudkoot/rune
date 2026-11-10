-- rows: exp.if.false tr.if
-- Report 3.6: if e1 then e2 else e3 is e2 when e1 is True and e3 when False, the other unevaluated; it is case e1 of
-- { True -> e2 ; False -> e3 }.
module Main (main) where

main :: IO ()
main = do
  print (if True then 1 else undefined, if False then undefined else 2 :: Int)
  print (case True of { True -> 1; False -> undefined }, case False of { True -> undefined; False -> 2 :: Int })
