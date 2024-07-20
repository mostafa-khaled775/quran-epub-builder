 "\n<p class=\"basmala\">بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ </p>\n" as $basmala
| group_by(.page)
| [
  .[]
  | map({sura: .sura_name_ar, text: .aya_text, num: .aya_no}) 
  | reduce .[] as $ayah (""; 
    .
    + if $ayah.num == 1 then "\n\n## \($ayah.sura)\n" else "" end
    + if $ayah.num == 1 and $ayah.sura != "الفَاتِحة" and $ayah.sura != "التوبَة" then $basmala else "" end
    + $ayah.text
    + " "
    )
  ]
| join("<div style=\"page-break-after: always;\"></div>")
