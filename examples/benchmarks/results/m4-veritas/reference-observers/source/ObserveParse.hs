module ObserveParse where
import Parse
import Unparse
import Token
import Tags
import Type_defs
import Core_datatype
import qualified Kernel as K
import ObserveProtocol(hex)
import Data.List(intercalate)
code n=[toEnum n]
sources=[
 ("forall",code 177++"x:U0.x=x"),
 ("lambda",code 236++"x:U0.x"),
 ("nested",code 177++"x:U0."++code 177++"y:U0.x=y"),
 ("booleans","true "++code 179++" false "++code 180++" true"),
 ("parentheses","(true "++code 180++" false) "++code 179++" true"),
 ("implication","[true] "++code 182++" false"),
 ("let","let x = U0 in x"),
 ("pair","U0,U1"),
 ("typed-pair","(U0,U1) typed "++code 211++"x:U2.U2"),
 ("indexed",code 168++"0,0"++code 169),
 ("undefined","missing"),
 ("empty",""),
 ("comment","% ignore this\nU1"),
 ("symbol","a+b^2")]
main=do
 writeFile"../parser-inputs.tsv"(unlines[n++"\t"++hex s|(n,s)<-sources])
 mapM_(\(n,s)->do
   let flag=parse_itm(default_tag_tbl,K.empty)s
   writeFile("../parse-"++n++".reference")(hex(unparse(Empty[])flag))
   writeFile("../tokens-"++n++".reference")(intercalate"\n"(map tok(tokenise s))))
  sources
 putStrLn"parser observations complete"
 where tok x=case x of { Rvd s->"r:"++hex s; Clr s->"c:"++hex s; Bdr _->"b:"++hex(disp_tk x);
                         IfxBdr s->"d:"++hex s; IfxOp s->"o:"++hex s; Scan_Err s->"e:"++hex s }
