module Main where
import LambdaLift
import Test
import Data.List(intercalate)
q=show
arr xs="["++intercalate "," xs++"]"
expr(EConst(CNum n))=arr[q"num",show n]
expr(EConst(CBool b))=arr[q"bool",if b then"true"else"false"]
expr(EConst(CFun n))=arr[q"fun",q n]
expr(EVar n)=arr[q"var",q n]
expr(EAp a b)=arr[q"app",expr a,expr b]
expr(ELam args body)=arr[q"lam",arr(map q args),expr body]
expr(ELet rec defs body)=arr[q"let",if rec then"true"else"false",arr[ arr[q name,expr rhs]|(name,rhs)<-defs],expr body]
scs defs=arr[arr[q name,arr(map q args),expr body]|(name,args,body)<-defs]
num n=EConst(CNum n)
fun n=EConst(CFun n)
v=EVar
app=EAp
bin f a b=app(app(fun f)a)b
cases=[
 ("identity",app(ELam["x"](v"x"))(num 42)),
 ("capture",ELet False[("a",num 2)](app(ELam["x"](bin"+"(v"a")(v"x")))(num 40))),
 ("multi-lambda",app(app(ELam["x","y"](bin"+"(v"x")(v"y")))(num 17))(num 25)),
 ("shadow",app(app(ELam["x"](ELam["x"](v"x")))(num 1))(num 42)),
 ("unused-cycle",ELet True[("bad",v"bad")](num 42)),
 ("factorial",ELet True[("fac",ELam["n"](app(app(app(fun"if")(bin"=="(v"n")(num 0)))(num 1))(bin"*"(v"n")(app(v"fac")(bin"-"(v"n")(num 1))))))](app(v"fac")(num 6))),
 ("fixed-program",program)]
main=putStrLn(arr[ arr[q name,expr input,scs(lambdaLift input),scs(fullyLazyLift input)]|(name,input)<-cases])
