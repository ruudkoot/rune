module Main where
import S_Array
import Input_proc
import Elefac
import Chl_routs
import Chl_decomp
import Chl_method
import GHC.Float(castFloatToWord32)
bits=castFloatToWord32
realArray a=map(\(i,v)->(i,bits v))(s_assocs a)
blockArray a=map(\(i,(diag,off))->(i,(s_bounds diag,realArray diag,s_bounds off,
 map(\(j,(start,values))->(j,(start,map bits values)))(s_assocs off))))(s_assocs a)
main=do
 header<-readFile "../source/fluid.stdin"
 let(file,config)=read_fs_cs header
 dataText<-readFile("../source/"++file)
 let(e,n,p,vs,ps,coord,(initP,(u1,u2)),(all,(xf,yf)),fixed)=read_data dataText
 writeFile "../mesh-input.reference"(show(e,n,p,s_assocs vs,s_assocs ps,
  map(\(i,(x,y))->(i,(bits x,bits y)))(s_assocs coord),realArray initP,realArray u1,realArray u2,
  s_assocs all,s_assocs xf,s_assocs yf,fixed)++"\n")
 let factors=get_el_det_fac e coord ps
 let(initial,mapping)=orded_mat p factors ps fixed
 writeFile "../mesh-order.reference"(show(blockArray initial,s_assocs mapping)++"\n")
 let fac=chl_factor initial
 writeFile "../mesh-factor.reference"(show(blockArray fac)++"\n")
 let solution=chl_method(fac,mapping)(s_listArray(1,p)[fromIntegral(i*i)|i<-[1..p]])0.25
 writeFile "../mesh-solution.reference"(show(realArray solution)++"\n")
 print(e,n,p,config)
