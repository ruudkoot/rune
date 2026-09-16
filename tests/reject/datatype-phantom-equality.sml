datatype 'a phantom = Phantom
datatype 'a link = Link of 'a * 'a phantom
val Link (_,p) = Link (fn x => x,Phantom)
val _ = p = p
