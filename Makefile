all: tdcf-tables.html

pdf: tdcf-tables.pdf

tdcf-tables.html: tdcf-tables.adoc
	asciidoctor tdcf-tables.adoc

tdcf-tables.adoc: csv-compile.rb
	ruby csv-compile.rb GRIB2 BUFR4 CCT

tdcf-tables.pdf: tdcf-tables.adoc
	asciidoctor-pdf -a pdf-theme=themes/japanese-theme.yml -a lang=ja tdcf-tables.adoc
