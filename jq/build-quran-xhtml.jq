 "\n<p class=\"basmala\">﷽</p>\n" as $basmala
| group_by(.page)
| sort_by(first | .page)
| [
  .[]
  | map({sura: .sura_name_ar, text: .aya_text, num: .aya_no, sura_no}) 
  | reduce .[] as $ayah (""; 
    .
    + if $ayah.num == 1 then
	if $ayah.sura_no != 1 then "\n</section>\n" else "" end
	+ "<section id=\"\($ayah.sura)\" class=\"level2\">\n<h2>\($ayah.sura)</h2>\n"
	else "" end
    + if $ayah.num == 1 and $ayah.sura_no != 1 and $ayah.sura_no != 9 then $basmala else "" end
    + $ayah.text
    + " "
    )
  ]
| join("\n<div style=\"page-break-after: always;\"></div>")
