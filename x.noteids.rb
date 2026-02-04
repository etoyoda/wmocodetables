#!/usr/bin/ruby

# noteIDs の用例を全数検査して、指定の正規表現に収まることを確認するスクリプト
# けっこうイレギュラーがある

require 'csv'
Dir.glob('{GRIB2,BUFR4,CCT}/*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  next unless tab.headers.include?('noteIDs')
  puts cfnam
  tab.each{|row|
    next unless row['noteIDs']
    case row['noteIDs']
    when /^\d+(,\d+)*$/ then
      puts row['noteIDs'].inspect
    else
      puts row.inspect
    end
  }
}
