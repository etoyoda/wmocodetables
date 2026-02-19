#!/usr/bin/ruby

require 'csv'

basedir='GRIB2'

ttab=CSV.read(File.join(basedir,'notes/CodeFlag_table.csv'),headers:true)
tables=ttab.map{|r| r['tableNo']}.sort

csvs=Dir.glob(File.join(basedir,'GRIB2_CodeFlag_*.csv')).map{|fn|
  unless /\bGRIB2_CodeFlag_(\d+(?:_\d+)+)_[A-Za-z]+_en\.csv$/===fn
    raise fn
  end
  a=$1.split(/_/,4).map{|s|s.to_i}
  a.push(0) until a.size >= 4
  a.join('.')
}.sort

p tables-csvs
p csvs-tables
