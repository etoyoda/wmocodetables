require 'csv'
Dir.glob('{GRIB2,BUFR4,CCT}/*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  next unless tab.headers.include?('Note_en')
  puts cfnam
  tab.each{|row|
    next unless row['Note_en']
    puts row['Note_en'].inspect
  }
}
