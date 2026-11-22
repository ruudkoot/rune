-- rows: R76
-- Report 4.3.2: "It is illegal to give a binding for a class method that is not in scope": C imported without m.
module Main (main) where

import Klass (C)

instance C Bool where
  m _ = 0

main :: IO ()
main = return ()
