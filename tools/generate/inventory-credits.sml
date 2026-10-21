(* Reviewed header facts. A name is recorded only with the corresponding
   source evidence; an absent dataset or notice is never invented. *)
structure GenerateInventoryCredits =
struct
  open GenerateInventoryBase
  type credit={authors:string list ref,evidence:string list ref,notices:string list ref,inputs:string list ref,context:string list ref}
  fun add target value=target:=value:: !target
  fun parentFacts source path root parent (c:credit) =
    let fun prefix file n=if n<=0 then readText file else short n (readText file)
        fun fact paths file limit tests authors evidence notices =
          if not (List.exists (fn p => p=path) paths) then () else
           let val file=parent ^ "/" ^ file
           in if not (regular file) then () else
               let val text=prefix file limit
               in if List.all (fn required => String.isSubstring required text) tests then
                    (List.app (add (#authors c)) authors;List.app (add (#evidence c)) evidence;List.app (add (#notices c)) notices) else () end end
        fun input paths file tag=if not (List.exists (fn p => p=path) paths) then () else
           let val file=parent ^ "/" ^ file in if regular file then (add (#inputs c) (relative root file);add (#evidence c) (relative root file ^ ":" ^ tag)) else () end
        fun context paths file=if List.exists (fn p => p=path) paths andalso regular (parent ^ "/" ^ file) then add (#context c) (parent ^ "/" ^ file) else ()
        val ()=if source<>"nofib" then () else
          (fact ["real/anna"] "Main.hs" 0 ["Jules's Strictness Analyser, version 0.400","Copyright (c) Julian Seward 1992"] ["Julian Seward (program banner)"] [path ^ "/Main.hs:versioned-program-copyright-banner"] [];
           fact ["real/hpg"] "hpg.tex" 0 ["\\title{The Haskell Program Generator}","\\author{N D North","ndn@seg.npl.co.uk"] ["N. D. North"] [path ^ "/hpg.tex:program-author-title-and-address"] [];
           fact ["real/hpg"] "hpg.tex" 0 ["% Crown Copyright 1992"] [] [] [path ^ "/hpg.tex:Crown-Copyright-1992"];
           fact ["real/reptile"] "Main.hs" 1000 ["-- LML original: Sandra Foubister, 1990"] ["Sandra Foubister (LML original)"] [path ^ "/Main.hs:LML-original-credit"] [];
           fact ["real/reptile"] "Main.hs" 1000 ["-- Haskell translation: Colin Runciman, May 1991"] ["Colin Runciman (Haskell translation)"] [path ^ "/Main.hs:Haskell-port-credit"] [];
           (if path="real/fluid" andalso regular (parent ^ "/Defs.hs") then
               let val text=prefix (parent ^ "/Defs.hs") 1000
               in if T.matches "(^|[^A-Za-z0-9_])XZ,\\s*24/10/91([^A-Za-z0-9_]|$)" text andalso T.matches "(^|[^A-Za-z0-9_])XZ,\\s*19/2/92([^A-Za-z0-9_]|$)" text then (add (#authors c) "XZ (source initials)";add (#evidence c) (path ^ "/Defs.hs:dated-source-initials-not-expanded")) else () end else ());
           input ["real/fluid"] "runtime_files/chan8.dat" "runtime-mesh-input";
           fact ["real/fluid"] "runtime_files/chan8.dat" 1000 ["TEST CHANNEL PROBLEM WITH NONISOTHERMAL FLOW"] [] [path ^ "/runtime_files/chan8.dat:channel-model-header"] [];
           fact ["spectral/hartel/nucleic2"] "Main.hs" 0 ["Author: Marc Feeley (feeley@iro.umontreal.ca)","Last modified: June 6, 1994"] ["Marc Feeley"] [path ^ "/Main.hs:molecular-search-author-and-date"] [];
           fact ["spectral/hartel/nucleic2"] "Main.hs" 0 ["#ifdef USE_HARTEL_LAZINESS","make_relative_nuc t n"] [] [path ^ "/Main.hs:on-demand-and-shared-coordinate-variants"] [];
           fact ["spectral/hartel/nucleic2"] "README" 0 ["Haskell version (for HBC, by Lennart Augustsson)"] ["Lennart Augustsson (Haskell version)"] [path ^ "/README:Haskell-port-authorship"] [];
           fact ["spectral/hartel/nucleic2"] "README" 0 ["UPDATE(2017.01)","non-Haskell versions of the program"] [] [path ^ "/README:historical-archive-files-removed-in-2017"] [];
           context ["spectral/hartel/nucleic2"] "MAIL";
           fact ["spectral/hartel/nucleic2"] "MAIL" 0 ["From: pieter@fwi.uva.nl (Pieter H. Hartel)","Subject: Request participation pseudo knot benchmark","Mon, 13 Jun 1994"] ["Pieter H. Hartel (benchmark coordination)"] [path ^ "/MAIL:1994-benchmark-coordination-and-porting-invitation"] [];
           (if path="spectral/hartel/nucleic2" andalso regular (parent ^ "/unboxery.h") then let val text=readText (parent ^ "/unboxery.h")
             in if T.matches "^#define FLOAT_TY Float\\s*$" text andalso String.isSubstring "#define FL_LIT(x) (x)" text then add (#evidence c) (path ^ "/unboxery.h:boxed-Float-default") else () end else ());
           fact ["gc/happy"] "Main.lhs" 1000 ["(c) 1993-2003 Andy Gill, Simon Marlow"] ["Andy Gill","Simon Marlow"] ["gc/happy/Main.lhs:original-authors"] [];
           fact ["gc/happy"] "TestInput.y" 1000 ["(c) The University of Glasgow 1997-2003","Author(s): Simon Marlow, Sven Panne 1997, 1998, 1999"] ["Sven Panne (GHC grammar input)"] ["gc/happy/TestInput.y:individual-dataset-notice"] ["gc/happy/TestInput.y:Glasgow-copyright-and-grammar-authors"];
           fact ["gc/happy"] "GenUtils.lhs" 1000 ["All the code below is understood to be in the public domain."] [] ["gc/happy/GenUtils.lhs:individual-public-domain-statement"] ["gc/happy/GenUtils.lhs:public-domain-statement"];
           fact ["gc/happy"] "Makefile" 0 ["NORM_OPTS = TestInput.y","EXCLUDED_SRCS += TestInput.hs"] [] ["gc/happy/Makefile:grammar-input-and-generated-parser-exclusion"] [];
           fact ["spectral/simple"] "Main.hs" 0 ["Original Author: Kattamuri Ekanadham <EKNATH@ibm.com>","translated to haskell by an id to ph translator"] [] ["spectral/simple/Main.hs:Id-author-and-anonymous-translator-role"] [];
           fact ["spectral/simple"] "simple.c" 1000 ["Andy Shaw and Kofi Fynn.","Wed Feb  2 14:59:18 EST 1994"] ["Andy Shaw (C comparator)","Kofi Fynn (C comparator)"] ["spectral/simple/simple.c:C-comparator-authors"] [];
           context ["spectral/simple"] "MAIL";
           fact ["spectral/simple"] "MAIL" 0 ["RPaul Johnson told me","This version may be useful because it is in 1.2 Haskell"] ["RPaul Johnson (Haskell/pH correspondence)"] ["spectral/simple/MAIL:Haskell-port-correspondence"] [];
           fact ["spectral/simple"] "MAIL" 0 ["Here is the fortran in its original form from Olaf Lubeck:"] ["Olaf Lubeck (Fortran supplier, not asserted sole author)"] ["spectral/simple/MAIL:Fortran-supplier"] [];
           fact ["spectral/simple"] "Makefile" 0 ["SRCS = Main.hs"] [] ["spectral/simple/Makefile:excludes-C-and-Fortran-comparators"] [];
           fact ["real/lift"] "LambdaLift.lhs" 0 ["\\title{A modular fully-lazy lambda lifter in \\Haskell{}}","Simon L Peyton Jones","David Lester","\\begin{abstract}"] ["Simon L. Peyton Jones","David Lester"] ["real/lift/LambdaLift.lhs:executable-paper-title-and-author-block"] [];
           fact ["real/fem"] "README" 0 ["Dr. Junxian Liu","Department of Computing","Imperial College, London SW7 2BZ"] ["Junxian Liu"] ["real/fem/README:author-and-model-description"] [];
           List.app (fn file => input ["real/fem"] file "reviewed-model-input") ["data.0","data.1","data.2","data.3"];
           fact ["gc/cacheprof","real/cacheprof"] "Main.hs" 2500 ["Copyright (C) 1999 Julian Seward (jseward@acm.org)","either version 2 of the","License, or (at your option) any later version."] ["Julian Seward"] [path ^ "/Main.hs:author-and-GPL2-or-later-heading"] [];
           input ["gc/cacheprof","real/cacheprof"] "cacheprof.full" "complete-assembly-input-reservoir";
           fact ["gc/fulsom/Main.hs","real/fulsom/Main.hs","gc/fulsom/Bah.hs","real/fulsom/Bah.hs"] "Interval.hs" 2500 ["Copyright 1990,1991,1992,1993 Duncan Sinclair","Permissiom to use, copy, modify, and distribute this software for any","copyright notice and this permission notice appear in all copies"] ["Duncan Sinclair"] [relative root (parent ^ "/Interval.hs") ^ ":author-and-individual-permission"] [];
           fact ["real/hidden"] "MAIL" 0 ["From:    ramaer@cs.utwente.nl (Mark Ramaer)","Certainly.  However, I should note that the program is written by\nStef Joosten (joosten@cs.utwente.nl) in Miranda(TM) and I have translated\nit to Haskell to play with overloading; I also added the memoising."] ["Stef Joosten","Mark Ramaer"] ["real/hidden/MAIL:authorship-and-nofib-permission"] ["real/hidden/MAIL:nofib-permission"];
           fact ["real/gg"] "gg.1" 0 [".SH AUTHOR\nIain Checkland, University of York."] ["Iain Checkland"] ["real/gg/gg.1:author-section"] [];
           fact ["spectral/fft2"] "Main.lhs" 0 ["Rex Page (rpage@trc.amoco.com)","Amoco Production Research, Sep 1992"] ["Rex Page"] ["spectral/fft2/Main.lhs:author-header"] [];
           fact ["spectral/lambda"] "Main.hs" 0 ["-- From Mark: marku@cs.waikato.ac.nz [Nov 2001]"] ["Mark (marku@cs.waikato.ac.nz)"] ["spectral/lambda/Main.hs:author-header"] [];
           fact ["spectral/para"] "Main.lhs" 0 ["% \tA program by Oege de Moor and Jeremy Gibbons"] ["Oege de Moor","Jeremy Gibbons"] ["spectral/para/Main.lhs:author-heading"] [];
           fact ["spectral/para"] "runtime_files/input-data" 0 ["Far From The Madding Crowd, by Thomas Hardy","*END*THE SMALL PRINT! FOR PUBLIC DOMAIN ETEXTS*Ver.04.29.93*END*"] [] ["spectral/para/runtime_files/input-data:individual-dataset-notice"] ["spectral/para/runtime_files/input-data:Project-Gutenberg-1993-notice"];
           fact ["spectral/sphere"] "Main.lhs" 0 ["16 July, 1998, David J. King","This is a Haskell port of the Id version from the Impala"] ["David J. King"] ["spectral/sphere/Main.lhs:authorship-and-port-history"] [];
           fact ["spectral/rewrite"] "Main.lhs" 2500 ["Mike Spivey,","St. George's Day, 1991.","[converted to Haskell by partain]"] ["Mike Spivey","partain (Haskell conversion)"] ["spectral/rewrite/Main.lhs:Orwell-author-and-Haskell-conversion-heading"] [];
           fact ["spectral/dom-lt"] "Dom.hs" 0 ["Copyright   :  (c) Matt Morrow 2009","License     :  BSD3"] ["Matt Morrow"] ["spectral/dom-lt/Dom.hs:algorithm-author-and-BSD3-heading"] [];
           fact ["spectral/multiplier"] "Main.hs" 0 ["-- John O'Donnell, University of Glasgow. jtod@dcs.glasgow.ac.uk","-- Copyright (c) 1992 by John T. O'Donnell"] ["John T. O'Donnell"] ["spectral/multiplier/Main.hs:author-and-copyright-heading"] [];
           fact ["spectral/expert"] "README" 0 ["Ian Holyer\nMarch 1993"] ["Ian Holyer"] ["spectral/expert/README:authorship-and-adaptation-heading"] [];
           fact ["spectral/knights"] "README" 0 ["The Knights Tour in Haskell\n---------------------------\n\nJonathan Hill\n"] ["Jonathan Hill"] ["spectral/knights/README:authorship-heading"] [];
           fact ["gc/linear","real/linear"] "Main.lhs" 0 ["Written by Brian D. Moe (Summer 1990)","Modified by Kamini Shenoi (Summer 1991)","Converted to Haskell by Ian R McLelland and Cordelia V Hall (Nov 1992)"] ["Brian D. Moe","Kamini Shenoi","Ian R. McLelland","Cordelia V. Hall"] [path ^ "/Main.lhs:authorship-and-conversion-roles"] [];
           fact ["gc/linear","real/linear"] "Input.lhs" 0 ["Roger L. Wainwright  6-8-90"] ["Roger L. Wainwright"] [path ^ "/Input.lhs:data-representation-credit"] [];
           fact ["gc/linear","real/linear"] "Input.lhs" 0 ["written by Dan Vasicek and copied from his directory 6/22/90"] ["Dan Vasicek"] [path ^ "/Input.lhs:input-reader-credit"] [] )
        val ()=if source<>"sandmark" then () else
          (fact ["benchmarks/lexifi-g2pp/main.exe"] "main.ml" 2500 ["Copyright (C) 2000-2013 LexiFi SAS. All rights reserved.","either version 3 of the License"] ["LexiFi SAS (copyright holder)"] [relative root (parent ^ "/main.ml") ^ ":copyright-holder-and-GPL3-heading"] [];
           fact ["benchmarks/multicore-minilight/sequential/minilight.exe"] "minilight.ml" 1000 ["MiniLight OCaml : minimal global illumination renderer","Copyright (c) 2006-2008, Harrison Ainsworth / HXA7241."] ["Harrison Ainsworth / HXA7241"] [relative root (parent ^ "/minilight.ml") ^ ":author-and-release-heading"] [];
           fact ["benchmarks/sauvola/contrast.exe"] "contrast.ml" 2500 ["(c) 2009-12 Andreas Romeyke","GNU General Public License","(v2.0 or higher)"] ["Andreas Romeyke"] [relative root (parent ^ "/contrast.ml") ^ ":author-and-GPL2-heading"] [];
           fact ["benchmarks/benchmarksgame/regexredux2.exe"] "regexredux2.ml" 0 ["regex-dna program contributed by Christophe TROESTLER","updated by Roman Kashitsyn: use Bytes instead of String"] ["Roman Kashitsyn"] [relative root (parent ^ "/regexredux2.ml") ^ ":Bytes-adaptation-credit"] [])
    in () end
  fun headers source path root files (c:credit) =
    let fun one file =
          let val header=short 8000 (readText file) val rel=relative root file
              fun contains s=String.isSubstring s header
              fun fact paths tests authors tag=if List.exists (fn p => p=path) paths andalso List.all contains tests then
                    (List.app (add (#authors c)) authors;add (#evidence c) (rel ^ ":" ^ tag)) else ()
              val ()=if source<>"nofib" then () else
                (fact ["gc/circsim","spectral/circsim"] ["The Circuit Simulator example\nDavid J. King & John O'Donnell\nJanuary, 1998"] ["David J. King","John O'Donnell"] "authorship-heading";
                 fact ["spectral/atom"] ["A kernel fragment from a program written by\n\t\tRon Legere"] ["Ron Legere"] "attribution-header";
                 fact ["spectral/exact-reals"] ["-- Taken from \"The worlds shortest correct exact real arithmetic program?\"\n-- David Lester, Information and Computation 216, pp39-46, 2012, Elsevier"] ["David Lester"] "paper-attribution";
                 if List.exists (fn p => p=path) ["real/pic","real/gamteb"] andalso T.matches "^--[ \t]+Patricia Fasel\n--[ \t]+Los Alamos National Laboratory" header then
                       (add (#authors c) "Patricia Fasel";add (#evidence c) (rel ^ ":author-heading")) else ();
                 if path="real/prolog" andalso T.matches "^-- Mark P\\. Jones November 1990$" header then (add (#authors c) "Mark P. Jones";add (#evidence c) (rel ^ ":author-heading")) else ();
                 if path="real/mkhprog" andalso List.exists (fn line => line="\\author{N D North\\\\") (lines header) andalso List.exists (fn line => line="% Crown Copyright 1992") (lines header) then
                     (add (#authors c) "N. D. North";add (#evidence c) (rel ^ ":author-and-crown-heading")) else ())
              val prime=source="nofib" andalso path="spectral/primetest" andalso List.exists (fn line => line="\\def\\author{David Lester}") (lines header)
              val ()=if prime then (add (#authors c) "David Lester";add (#evidence c) (rel ^ ":author-macro")) else ()
              val ()=if T.matches "[Cc]opyright|[Ll]icen[sc]e|[Ww]ritten by|[Aa]uthor:|[Tt]ranslated" header then add (#notices c) (rel ^ ":header") else ()
              val attribution=TerminalPattern.compile false "([Ww]ritten|[Tt]ranslated|[Pp]orted|[Cc]ontributed)( to [^\n]*)? by [^\n]+|[Aa]uthors?: [^\n]+"
              fun loop start=case TerminalPattern.find attribution header start of NONE => () | SOME (a,b) =>
                let val text=String.substring (header,a,b-a)
                    val value=if String.isPrefix "Author" text orelse String.isPrefix "author" text then #2 (valOf (T.splitAt ": " text)) else #2 (valOf (T.splitAt " by " text))
                    val author=Substring.string (Substring.dropr (fn c => Char.contains " *()-" c) (Substring.dropl (fn c => Char.contains " *()-" c) (Substring.full value)))
                    val author=if author="Marc Feeley (feeley@iro.umontreal.ca" then "Marc Feeley" else author
                    val ()=if prime andalso a>0 andalso String.sub (header,a-1) = #"$" then () else if length (Utf8.explode author)<=180 then add (#authors c) author else ()
                in loop b end
          in loop 0 end
    in List.app one files end

end
