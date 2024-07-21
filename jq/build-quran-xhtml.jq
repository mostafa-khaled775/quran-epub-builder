 "\n<p class=\"basmala\">﷽</p>\n" as $basmala
| map({sura_en: .sura_name_en, sura: .sura_name_ar, text: .aya_text, num: .aya_no, sura_no,
  page: (if .page | type == "string" then .page | [ scan("[0-9]+") ][0] | tonumber else .page end)})
| group_by(.page)
| [
  .[]
  | reduce .[] as $ayah (""; 
    .
    + if $ayah.num == 1 then
	if $ayah.sura_no != 1 then "\n</section>\n" else "" end
	+ "<section id=\"sura-\($ayah.sura_no)\" class=\"level2\">\n<h2>\($ayah.sura)</h2>\n"
	else "" end
    + if $ayah.num == 1 and $ayah.sura_no != 1 and $ayah.sura_no != 9 then $basmala else "" end
    + $ayah.text
    + " "
    )
  ]
| join("\n<div style=\"page-break-after: always;\"></div>\n")
