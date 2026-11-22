-- Main's import of List names the library's, until a module of the
-- program's own is List (build-cache-issues.md, issue 37's A: the modules
-- imported, not only what each exports).
module Main where

import List (sort)

main :: IO ()
main = print (sort [3, 1, 2 :: Int])
