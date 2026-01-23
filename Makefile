all: GRIB2-tables.html BUFR4-tables.html CCT-tables.html

GRIB2-tables.html: GRIB2-tables.adoc
	asciidoctor GRIB2-tables.adoc

BUFR4-tables.html: BUFR4-tables.adoc
	asciidoctor BUFR4-tables.adoc

CCT-tables.html: CCT-tables.adoc
	asciidoctor CCT-tables.adoc

GRIB2-tables.adoc: csv-compile.rb
	ruby csv-compile.rb GRIB2

BUFR4-tables.adoc: csv-compile.rb
	ruby csv-compile.rb BUFR4

CCT-tables.adoc: csv-compile.rb
	ruby csv-compile.rb CCT
