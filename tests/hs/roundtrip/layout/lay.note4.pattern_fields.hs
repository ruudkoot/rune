module M where
data R = R {
a :: Int,
  b :: Int
}
f R { a = x,
b = y } = x
