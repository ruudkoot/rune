-- A unit whose check makes fresh type variables and dictionaries, which
-- the units after it were numbered after (build-cache-issues.md, issue 30).
module A where

data Box a = Box a deriving (Eq, Show)

twice :: (a -> a) -> a -> a
twice f = f . f

describe :: (Show a, Eq a) => a -> a -> String
describe x y = if x == y then show x else show y
