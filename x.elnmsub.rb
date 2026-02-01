require 'csv'
Dir.glob('{GRIB2,BUFR4,CCT}/*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  next unless tab.headers.include?('EntryName_sub1_en')
  puts cfnam
  tab.each{|row|
    next if row['EntryName_sub1_en'].nil? and row['EntryName_sub2_en'].nil?
    puts row.inspect
  }
}
