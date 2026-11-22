-- rows: exp.comp.order exp.comp.lazy exp.comp.fail.skip exp.comp.guard exp.comp.shadow exp.comp.ex.nested tr.comp.true tr.comp.single tr.comp.guard tr.comp.gen tr.comp.let tr.comp.ok.fresh R17
-- Report 3.11: generators, guards and local bindings, in order, lazily; a failed match skips the element; each
-- generator's variables shadow; the Report's example; the translations, with a variable named ok.
module Main (main) where

main :: IO ()
main = do
  print [y | x <- [1, 2, 3], let y = x + 1, y > 2]
  print [(x, y) | x <- [1, 2], y <- "ab"]
  print (take 2 [x | x <- [1 ..]])
  print [x | Just x <- [Just 1, Nothing, Just 3]]
  print [x | x <- [1, 2, 3], odd x]
  let x = [[1, 2], [3]]
  print ([x | x <- x, x <- x], [z | y <- x, z <- y])
  print [x | xs <- [[(1, 2), (3, 4)], [(5, 4), (3, 2)]], (3, x) <- xs]
  print ([1 | True], [1 | False], [1 | True, True])
  print (let ok (Just x) = [x]
             ok _ = []
         in concatMap ok [Just 1, Nothing, Just 3])
  print (let z = 2 in [z * w | w <- [1, 2]], [z * w | let z = 2, w <- [1, 2]])
  print [ok | Just ok <- [Just 'a', Nothing]]
  print (let ok = 5 in [ok + y | y <- [1, 2]])
