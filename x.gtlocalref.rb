#!/usr/bin/ruby

require 'csv'

basedir='GRIB2'

tdb=Hash.new

Dir.glob(File.join(basedir,'GRIB2_Template_*.csv')).each{|fn|
  unless /\bGRIB2_Template_(\d+(?:_\d+)+)_[A-Za-z]+_(en|ja)\.csv$/===fn
    raise fn
  end
  tcode,lang=$1,$2
  next unless 'en'==lang
  a=tcode.split(/_/,2).map{|s|s.to_i}
  a.push(0) until a.size >= 2
  tname=a.join('.')
  next unless /^4/===tname
  table=CSV.read(fn,headers:true)
  table.each{|row|
    contents=row['Contents_en']
    next unless /defined by originating centre/===contents
    # p([tname,row['OctetNo'],contents])
    tdb[contents]=Hash.new unless tdb[contents]
    tdb[contents][tname]=row['OctetNo']
  }
}
p tdb


