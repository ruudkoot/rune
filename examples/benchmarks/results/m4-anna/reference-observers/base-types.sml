 val baseTypes:typeEnv=
   let val intBinary=cell(TArr(intType,cell(TArr(intType,intType))))
       val comparison=cell(TArr(intType,cell(TArr(intType,boolType))))
       val boolBinary=cell(TArr(boolType,cell(TArr(boolType,boolType))))
       val boolUnary=cell(TArr(boolType,boolType))
       val items=[("_not",boolUnary),("_+",intBinary),("_-",intBinary),("_*",intBinary),
          ("_/",intBinary),("_%",intBinary),("_<",comparison),("_<=",comparison),
          ("_==",comparison),("_~=",comparison),("_>=",comparison),("_>",comparison),
          ("_|",boolBinary),("_&",boolBinary),("_#",boolBinary)]
   in F.fromList(List.map(fn(n,t)=>(name n,cell(Scheme(F.empty(),t))))items)end
