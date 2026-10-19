module DomainObserver where
import BaseDefs
import AbstractVals2
import AbstractMisc
import SuccsAndPreds2
import Apply
import MyUtils
import Data.List(intercalate)
list f xs="["++intercalate ","(map f xs)++"]"
pair a b="("++a++","++b++")"
r Zero="0"
r One="1"
r Stop1="s1"
r(Up1 rs)="u1"++list r rs
r Stop2="s2"
r Up2="u2"
r(UpUp2 rs)="uu2"++list r rs
r(Rep x)="r"++rep x
rep(RepTwo f)="t"++fr f
rep(Rep1 f hs)="l"++pair(fr f)(list rep hs)
rep(Rep2 f m hs)="d("++intercalate ","[fr f,fr m,list rep hs]++")"
fr(Min1Max0 a xs ys)="("++intercalate ","[show a,list fe xs,list fe ys]++")"
fe(MkFrel rs)=list r rs
cons xs f=foldr(\x rest->"K.F.cons("++f x++","++rest++")")"(K.F.empty())"xs
sd Two="K.cell K.Two"
sd(Lift1 ds)="K.cell(K.Lift1("++cons ds sd++"))"
sd(Lift2 ds)="K.cell(K.Lift2("++cons ds sd++"))"
sd(Func ds d)="K.cell(K.Func("++cons ds sd++","++sd d++"))"
sr Zero="K.cell K.Zero"
sr One="K.cell K.One"
sr Stop1="K.cell K.Stop1"
sr(Up1 rs)="K.cell(K.Up1("++cons rs sr++"))"
sr Stop2="K.cell K.Stop2"
sr Up2="K.cell K.Up2"
sr(UpUp2 rs)="K.cell(K.UpUp2("++cons rs sr++"))"
sr(Rep x)="K.cell(K.Rep("++srep x++"))"
srep(RepTwo f)="K.cell(K.RepTwo("++sf f++"))"
srep(Rep1 f hs)="K.cell(K.Rep1("++sf f++","++cons hs srep++"))"
srep(Rep2 f m hs)="K.cell(K.Rep2("++sf f++","++sf m++","++cons hs srep++"))"
sf(Min1Max0 a xs ys)="K.makeFrontier(K.int "++show a++")("++cons xs sfe++")("++cons ys sfe++")"
sfe(MkFrel rs)="K.cell(K.MkFrel("++cons rs sr++"))"
domains=[Two,Lift1[Two],Lift2[Two],Lift1[Two,Two],Lift2[Two,Two],
 Func[Two]Two,Func[Two,Two]Two,Func[Two](Lift1[Two]),Func[Two](Lift2[Two]),Func[Func[Two]Two]Two]
main=do
 writeFile"../domain-cases.sml"("val cases=["++intercalate ","[pair(sd d)(cons(amAllRoutes d)sr)|d<-domains]++"]\n")
 let rows d=let rs=amAllRoutes d in
       [list r rs,pair(r(avTopR d))(r(avBottomR d)),
        list(\p->pair(show(avIsTopR p))(show(avIsBottomR p)))rs,
        list(\(x,y)->show(x << y))[(x,y)|x<-rs,y<-rs],
        list(\(x,y)->r(x \/ y))[(x,y)|x<-rs,y<-rs],
        list(\(x,y)->r(x /\ y))[(x,y)|x<-rs,y<-rs],
        list(\p->list r(spSuccsR d p))rs,list(\p->list r(spPredsR d p))rs]
 writeFile"../domains.reference"(unlines(concatMap rows domains))
 print(map(length.amAllRoutes)domains)
