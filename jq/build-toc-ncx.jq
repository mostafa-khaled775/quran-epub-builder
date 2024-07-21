group_by(.sura_name_ar)
  | sort_by(first | .sura_no)
  | reduce .[] as $sura ("";
    $sura[0].sura_name_ar as $name
    | $sura[0].sura_no as $num
    | . + "<navPoint id=\"navPoint-\($num)\"><navLabel><text>\($name)</text></navLabel><content src=\"text/quran.xhtml#\($name)\" /></navPoint>\n")
