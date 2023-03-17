str == "" {
   exit
}
{
   split($0, null, "\\<(" str "\\>)", b)
   for (i=1; i<=length(b); i++)
      gsub("\\<" b[i] "([|]|$)", "", str)
}
END {
   exit (str != "")
}
