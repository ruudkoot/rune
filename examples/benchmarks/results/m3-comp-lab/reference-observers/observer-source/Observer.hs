module Main where
import Kernel
import System.Environment
figures=[c_mini_figure,c_small_figure,c_figure,c_figure_l,c_figure_l_l]
main=do
 args<-getArgs
 case args of
  ["figures"]->mapM_ (\(i,fig)->putStrLn(show i++" "++show(map(map(\p->if f_is_black p then 'B' else ' '))fig))) (zip [0..] figures)
  [s,n,t,mode]->do
   let fig=figures!!read s
       size=read n
       image=f_n_fig size fig
       width=length(head image)
       pixels=map f_pix2range image
       f=if mode=="zift"then f_zift_l else f_no_zift
       (labels,raw,objects)=f_comp_lab_diff' f width pixels(read t)
   putStr(f_show_all_lab(labels,raw,objects)width)
  _->error"expected figures or selector,size,threshold,zift|plain"
