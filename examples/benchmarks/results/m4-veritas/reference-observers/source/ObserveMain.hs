module ObserveMain where
import qualified Main as V
import NofibUtils(hash)
import ObserveProtocol(hex)
import System.IO(openBinaryFile,IOMode(ReadMode),hGetContents)
main=do
 h<-openBinaryFile"veritas.stdin"ReadMode
 input<-hGetContents h
 let output=V.main' input
 writeFile"../full-protocol.reference"(hex output)
 writeFile"../full-hash.reference"(show(hash output))
 print(length input,length output,hash output)
