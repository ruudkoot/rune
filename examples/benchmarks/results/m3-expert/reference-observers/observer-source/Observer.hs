module Main where
import Expert
main = readFile "runtime_files/animals" >>= \animals -> getContents >>= putStr . process animals
