module Main where
import Arch_x86
main=mapM_ (\(opcode,info)->putStrLn(show opcode++"\t"++show info++"\t"++show(elem opcode nonJumpyOpcodes))) x86info
