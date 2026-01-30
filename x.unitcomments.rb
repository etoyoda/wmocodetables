require 'csv'
Dir.glob('{GRIB2,BUFR4,CCT}/*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  next unless tab.headers.include?('UnitComments_en')
  puts cfnam
  tab.each{|row|
    next if row['UnitComments_en'].to_s.empty?
    puts row.to_h.inspect
  }
}
