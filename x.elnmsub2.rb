#!/usr/bin/ruby
# EntryName_sub2_en の用例を調査するスクリプト
require 'csv'
Dir.glob('{GRIB2,BUFR4,CCT}/*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  next unless tab.headers.include?('EntryName_sub2_en')
  puts cfnam
  tab.each{|row|
    next if row['EntryName_sub2_en'].nil?
    puts row.inspect
  }
}
