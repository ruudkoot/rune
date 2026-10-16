module Main where
import Kernel
cases=[("repeat",["hello","hello","hello","hello","hello","hello"]),
       ("rotate",["I feel sad","something","I feel sad","different","I feel sad","other","I feel sad"]),
       ("trailing-I",["can you I"]),
       ("no-tail-default",["can you"]),
       ("fallback",["flibbertigibbet"]),
       ("punctuation",[" ... Hello?! ","Hello","Hello"])]
main=mapM_ printCase cases
printCase(name,input)=print(name,session initial[](filter(not.null)(map(words.trim)input)))
