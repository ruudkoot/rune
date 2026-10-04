# MLton's benchmark asks the system for the current directory and builds
# the absolute names of its inputs from it, so the length of the checkout's
# path was in the count (docs/testing.md, the program's name and
# arguments): a relative name counts the same wherever the tree is
s/OS\.FileSys\.getDir *()/"."/
