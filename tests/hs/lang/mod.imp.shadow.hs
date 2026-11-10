-- Report 5.5.2: a local binding shadows an imported name: let map = 1 in map.
main :: IO ()
main = print (let map = 1 in map :: Int)
