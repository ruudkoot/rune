module Layout where
-- The layout rule of 2.7 and 9.3: implicit blocks, explicit ones within
-- them and the reverse, empty items, the implicit close of parse-error(t),
-- and an explicit close brace that closes an implicit block (R2).

f x = case x of
        1 -> a
        2 -> b
        _ -> c
  where a = 1
        b = 2
        c = let d = 3
                e = 4 in d + e

g = do { x <- return 1 ;; return x ; }
h = do
      { x <- return 1
; return x }
i = let { a = 1; b = 2;
  c = 3 } in a + b + c

-- parse-error(t): the block closes at the token that cannot go on.
j = let y = 1 in y
k = (case 1 of y -> y)
l = [case 1 of y -> y, 2]
m = (do return 1, 2)
n = if case True of y -> y then 1 else 2
o = case case 1 of y -> y of z -> z
p = [x | x <- [1], let y = x, odd y]
q x | x > 0 = x
  where

-- R2: `}` closes the implicit block of the case inside the record.
data R = R { r :: Int }
s = R { r = case 1 of y -> y }

-- Several blocks closed by one line.
t = do
  do
    do
      return ()
u = 1

-- An empty where, a class with an empty body, and an empty let.
v = 1 where
class Empty a where
w = let {} in 1
x = let in 1

-- Explicit braces whose lines start left of an enclosing implicit block.
y = do
    let { z = 1
; zz = 2
}
    return z

-- Tabs count to the next multiple of eight.
tabbed = do
	return 1
        return 2
