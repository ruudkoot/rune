module ObserveProtocol where
import X_interface
import Edlib
import Type_defs
import Vtslib
import Data.Char(ord)
import Numeric(showHex)
import System.IO(openBinaryFile,IOMode(ReadMode),hGetContents)
hex :: String -> String
hex xs=concatMap(\c->let s=showHex(ord c)""in replicate(2-length s)'0'++s)xs
out value input=let((rest,_,_),bytes)=value(input,[0..],[1..])in hex bytes++":"++hex rest
act value input showValue=let((rest,_,ids),result,bytes)=value(input,[0..],[1..])in
 hex bytes++":"++hex rest++":"++case result of Bad msg->"bad="++hex msg;Ok x->showValue x
forms [OutText a,OutText b,OutText c,OutRadio d]="form="++concatMap(\s->hex s++";")[a,b,c,d]
forms _=error"unexpected form"
parsed NONE="none"
parsed(SOME xs)=forms xs
sendCases=[
 ("send-args",x_send_argL["abc","",map toEnum[0,255]]),
 ("form-output",(\xin->let(after,_,bytes)=x_form False[InComment"title",InMultiText"" "body",InRadio"kind"0["a","b"]]xin in(after,bytes))),
 ("set-parent",x_set_parent"yes""parent"),("set-node",x_set_node"node"),
 ("set-rw",x_set_rw"r"),("set-done",x_set_done"done"),
 ("set-goal",x_set_goal"yes""goal"),("set-tactic",x_set_tactic"t"),
 ("set-argument",x_set_argument"a"),("set-comment",x_set_comment"c"),
 ("set-subgoals",x_set_subgoals[("a","b"),("c","d")]),
 ("set-status",x_set_status"s"),("unset-parent",x_unset_parent),("bell",x_bell),
 ("show-tactics",x_show_tactics),("show-window",x_show_window),("hide-window",x_hide_window),
 ("set-full",x_set_full[2]"title""body"),("unset-full",x_unset_full),
 ("send-subterm",x_send_subtrm(STData[0,2]3 4[STData[]5 6[]]))]
main=do
 probeInput<-openBinaryFile"veritas.stdin" ReadMode
 input<-hGetContents probeInput
 mapM_(\(n,fn)->writeFile("../protocol-"++n++".reference")(out fn"rest"))sendCases
 writeFile"../protocol-parse-form.reference"(act x_get_form input parsed)
 writeFile"../protocol-command.reference"(act x_get_cmd"\27\&2\27\&A\1Quit\27\&4\27\&5rest"(\s->"cmd="++hex s))
 writeFile"../protocol-ignored-error.reference"(act(x_error"oops" /./(\_->reTurn(42::Int)))"\27\&9rest" show)
 writeFile"../protocol-ignored-value.reference"(act(reTurn(error"unneeded") /./(\_->reTurn(42::Int)))"rest" show)
 writeFile"../protocol-ignored-pair.reference"(act((reTurn(error"unneeded") /.>/ reTurn(42::Int)) /./(\(_,n)->reTurn n))"rest" show)
 writeFile"../protocol-handled-error.reference"(act(handle(return_err"failed")(\s->reTurn("handled:"++s)))"rest" hex)
 putStrLn"protocol observations complete"
