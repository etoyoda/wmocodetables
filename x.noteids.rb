require 'csv'
Dir.glob('{GRIB2,BUFR4,CCT}/*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  next unless tab.headers.include?('noteIDs')
  puts cfnam
  tab.each{|row|
    next unless row['noteIDs']
    puts row['noteIDs'].inspect
  }
}
