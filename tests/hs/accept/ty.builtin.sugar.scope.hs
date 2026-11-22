-- rows: ty.builtin.prefix.scope
-- Report 4.1.2: "the special syntax always denotes the built-in type constructors, whatever is in scope", in its prefix
-- forms too: a module that imports nothing of the Prelude and declares its own List.
module Builtin where

import Prelude ()

data List a = Nil

f :: [a] -> (a, a) -> (a -> a) -> () -> List a
f _ _ _ _ = Nil

g :: [] a -> (,) a a -> (->) a a -> List a
g _ _ _ = Nil
