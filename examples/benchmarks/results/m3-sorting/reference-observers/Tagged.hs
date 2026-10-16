module Main where
import Sort
import Data.List (intersperse)
data Tagged=T Int Int deriving Show
instance Eq Tagged where T a _==T b _=a==b
instance Ord Tagged where compare(T a _)(T b _)=compare a b
main=do
 let input=[T 1 0,T 0 1,T 1 2,T 0 3,T 1 4]
     sorts=[heapSort,insertSort,mergeSort,quickSort,quickSort2,quickerSort,treeSort,treeSort2]
 mapM_ (print.map(\(T _ label)->label).($input)) sorts
 print(map(\(T _ label)->label)((foldr(.)id(intersperse reverse sorts))input))
