(f `o` g) x = f (g x)
main = print ((id `o` id) 1)
