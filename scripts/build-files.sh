#!/bin/sh
# Bootstrap source lists from files blocks, following relative use edges.
# Config and entrypoint paths outside files blocks remain the caller's.
# The compiler's BuildFile module owns the full language/project semantics.
set -eu
awk '
function fail(message) { print "build-files: " message > "/dev/stderr"; exit 2 }
function canonical(path, a, stack, n, i, top, absolute, out) {
  absolute = substr(path,1,1)=="/"; n=split(path,a,"/"); top=0
  for(i=1;i<=n;i++) {
    if(a[i]=="" || a[i]==".") continue
    if(a[i]==".." && top>0 && stack[top]!="..") { delete stack[top]; top--; continue }
    if(a[i]==".." && absolute) continue
    stack[++top]=a[i]
  }
  out=absolute?"/":""
  for(i=1;i<=top;i++) out=out (i>1?"/":"") stack[i]
  return out==""?".":out
}
function directory(path, result) {
  result=path; if(sub(/\057[^\057]*$/, "", result)) return result==""?"/":result
  return "."
}
function resolved(parent, child) {
  if(substr(child,1,1)=="/") return canonical(child)
  return canonical(directory(parent) "/" child)
}
function pathword(word) {
  if(substr(word,1,1)=="\"") {
    if(substr(word,length(word),1)!="\"") fail("bootstrap paths must be whitespace-free: " word)
    return substr(word,2,length(word)-2)
  }
  return word
}
function scan(path, text, line, status, out, depth, n, i, c, quote, m, words, j, inside, target) {
  path=canonical(path)
  if(active[path]) fail("cyclic use of " path)
  if(visited[path]) return
  active[path]=1
  text=""
  while((status=(getline line < path))>0) text=text line "\n"
  if(status<0) fail("cannot read " path)
  close(path)
  out=""; depth=0; quote=0; n=length(text)
  for(i=1;i<=n;i++) {
    c=substr(text,i,2)
    if(!quote && c=="(*") { depth++; i++; continue }
    if(depth>0 && c=="*)") { depth--; i++; continue }
    if(depth>0) continue
    c=substr(text,i,1)
    if(c=="\"" && (i==1 || substr(text,i-1,1)!="\\")) quote=!quote
    out=out c
  }
  if(depth!=0) fail("unterminated comment in " path)
  m=split(out,words,/[ \t\r\n]+/); inside=0
  for(j=1;j<=m;j++) {
    if(words[j]=="") continue
    if(words[j]=="files") { inside=1; continue }
    if(words[j]=="end") { inside=0; continue }
    if(!inside && words[j]=="use") {
      if(++j>m) fail("use without a path in " path)
      target=pathword(words[j]); scan(resolved(path,target)); continue
    }
    if(inside) print resolved(path,pathword(words[j]))
  }
  delete active[path]; visited[path]=1
}
BEGIN { scan(ARGV[1]); exit }
' "$1"
