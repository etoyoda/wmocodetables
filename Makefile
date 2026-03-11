all: process.html tdcf-tables.html

pdf: process.pdf tdcf-tables.pdf

tdcf-tables.html: tdcf-tables.adoc
	asciidoctor -a lang=ja tdcf-tables.adoc

# old version
tdcf-bak.adoc: csv-compile.rb toppage-ja.txt resources.csv fixwmo.csv
	ruby csv-compile.rb GRIB2 BUFR4 CCT

tdcf-tables.adoc: sabun.rb template-ja.txt resources.csv fixwmo.csv
	ruby sabun.rb HEAD

tdcf-tables.pdf: tdcf-tables.adoc themes/japanese-theme.yml
	asciidoctor-pdf -a pdf-theme=themes/japanese-theme.yml -a lang=ja tdcf-tables.adoc

process.html: process.adoc
	asciidoctor -a lang=ja process.adoc

process.pdf: process.adoc themes/japanese-theme.yml
	asciidoctor-pdf -a pdf-theme=themes/japanese-theme.yml -a lang=ja process.adoc
