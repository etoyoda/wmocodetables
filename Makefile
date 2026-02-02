all: tdcf-tables.html

pdf: tdcf-tables.pdf

tdcf-tables.html: tdcf-tables.adoc
	asciidoctor tdcf-tables.adoc

tdcf-tables.adoc: csv-compile.rb toppage-ja.txt
	ruby csv-compile.rb GRIB2 BUFR4 CCT
	test ! -f tdcf-tables.adoc.bak || diff -u tdcf-tables.adoc.bak tdcf-tables.adoc || (rm -f tdcf-tables.adoc ; false)
	cp -f tdcf-tables.adoc tdcf-tables.adoc.bak

tdcf-tables.pdf: tdcf-tables.adoc
	asciidoctor-pdf -a pdf-theme=themes/japanese-theme.yml -a lang=ja tdcf-tables.adoc
