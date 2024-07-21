group_by(.sura_name_ar)
  | sort_by(first | .sura_no)
  | reduce .[] as $sura ("";
    $sura[0].sura_name_ar as $name
    | $sura[0].sura_no as $num
    | . + "<li id=\"toc-li-\($num)\"><a href=\"text/quran.xhtml#\($name)\">\($name)</a></li>\n")
