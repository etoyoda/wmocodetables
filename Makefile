all: process.html tdcf-diff.html tdcf-tables.html

pdf: process.pdf tdcf-diff.pdf tdcf-tables.pdf

tdcf-diff.html: tdcf-diff.adoc
	asciidoctor -a lang=ja tdcf-diff.adoc

tdcf-tables.html: tdcf-tables.adoc
	asciidoctor -a lang=ja tdcf-tables.adoc

# old version
tdcf-bak.adoc: csv-compile.rb toppage-ja.txt resources.csv fixwmo.csv
	ruby csv-compile.rb GRIB2 BUFR4 CCT

tdcf-diff.adoc: sabun.rb resources.csv fixwmo.csv
	ruby sabun.rb HEAD -FT2026-1
	test -f tdcf-diff.adoc.bak || cp tdcf-diff.adoc tdcf-diff.adoc.bak
	diff tdcf-diff.adoc.bak tdcf-diff.adoc

tdcf-diff.pdf: tdcf-diff.adoc themes/japanese-theme.yml
	asciidoctor-pdf -a pdf-theme=themes/japanese-theme.yml -a lang=ja tdcf-diff.adoc

tdcf-tables.adoc: sabun.rb template-ja.txt resources.csv fixwmo.csv
	ruby sabun.rb HEAD
	test -f tdcf-tables.adoc.bak || cp tdcf-tables.adoc tdcf-tables.adoc.bak
	diff tdcf-tables.adoc.bak tdcf-tables.adoc

tdcf-tables.pdf: tdcf-tables.adoc themes/japanese-theme.yml
	asciidoctor-pdf -a pdf-theme=themes/japanese-theme.yml -a lang=ja tdcf-tables.adoc

process.html: process.adoc
	asciidoctor -a lang=ja process.adoc

process.pdf: process.adoc themes/japanese-theme.yml
	asciidoctor-pdf -a pdf-theme=themes/japanese-theme.yml -a lang=ja process.adoc
