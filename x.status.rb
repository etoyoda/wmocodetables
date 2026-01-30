require 'csv'
Dir.glob('{GRIB2,BUFR4,CCT}/*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  next unless tab.headers.include?('Status')
  puts cfnam
  tab.each{|row|
    next if /^(Operational|Deprecated)$/===row['Status']
    puts row.to_h.inspect
  }
}
