fun f x = let val g = fn y => x y in (g 1,g true) end
