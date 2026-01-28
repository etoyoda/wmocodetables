all: tdcf-tables.html

tdcf-tables.html: tdcf-tables.adoc
	asciidoctor tdcf-tables.adoc

tdcf-tables.adoc: csv-compile.rb
	ruby csv-compile.rb GRIB2 BUFR4 CCT
