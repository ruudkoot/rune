-- An instance of another module's class that leaves `describe` out: its
-- dictionary is made of the class's default where the class has one.
module I where

import C

data T = T

instance Describe T where
  name _ = "T"
