#!/usr/bin/ruby

require 'csv'

basedir='GRIB2'

ttab=CSV.read(File.join(basedir,'notes/Template_table.csv'),headers:true)
tables=ttab.map{|r| r['templateNo']}.sort
raise if tables.empty?

csvs=Dir.glob(File.join(basedir,'GRIB2_Template_*.csv')).map{|fn|
  unless /\bGRIB2_Template_(\d+(?:_\d+)+)_[A-Za-z]+_en\.csv$/===fn
    raise fn
  end
  a=$1.split(/_/,2).map{|s|s.to_i}
  a.push(0) until a.size >= 2
  a.join('.')
}.sort

puts "= only in notes/Template_table.csv:"
p tables-csvs
puts "= only GRIB2_Template_*.csv present:"
p csvs-tables
