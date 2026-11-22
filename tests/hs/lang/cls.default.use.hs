-- rows: cls.default.override cls.default.mutual cls.inst.missing.default
-- Report 4.3.1, 4.3.2: an instance without a method runs the class's default, one with it runs its own; mutual defaults
-- with one method defined.
module Main (main) where

class Shape a where
  area :: a -> Int
  name :: a -> String
  name _ = "shape"

data Sq = Sq Int
data Ci = Ci Int

instance Shape Sq where
  area (Sq s) = s * s

instance Shape Ci where
  area (Ci r) = 3 * r * r
  name _ = "circle"

class Eqish a where
  eq, ne :: a -> a -> Bool
  eq x y = not (ne x y)
  ne x y = not (eq x y)

instance Eqish Bool where
  eq a b = a == b

main :: IO ()
main = print (name (Sq 2), area (Sq 2), name (Ci 1), ne True False, eq True True)
