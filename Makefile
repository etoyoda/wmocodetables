all: tdcf-tables.html process.html

pdf: tdcf-tables.pdf

tdcf-tables.html: tdcf-tables.adoc
	asciidoctor -a lang=ja tdcf-tables.adoc

tdcf-tables.adoc: csv-compile.rb toppage-ja.txt resources.csv fixwmo.csv
	ruby csv-compile.rb GRIB2 BUFR4 CCT
	test ! -f tdcf-tables.adoc.bak || diff -u tdcf-tables.adoc.bak tdcf-tables.adoc || (rm -f tdcf-tables.adoc ; false)
	cp -f tdcf-tables.adoc tdcf-tables.adoc.bak

tdcf-tables.pdf: tdcf-tables.adoc
	asciidoctor-pdf -a pdf-theme=themes/japanese-theme.yml -a lang=ja tdcf-tables.adoc

process.html: process.adoc
	asciidoctor -a lang=ja process.adoc

process.pdf: process.adoc
	asciidoctor-pdf -a pdf-theme=themes/japanese-theme.yml -a lang=ja process.adoc
