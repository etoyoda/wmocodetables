require 'csv'
db=Hash.new
Dir.glob('{GRIB2,BUFR4,CCT}/*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  next unless tab.headers.include?('Status')
  puts cfnam
  tab.each{|row|
    status=row['Status'].inspect
    next if '"Operational"'==status
    puts row.to_h.inspect unless '"Deprecated"'==status
    db[status]=Hash.new unless db[status]
    db[status][cfnam]=true
  }
}

db.keys.sort.each{|status|
  puts "== status #{status}"
  db[status].keys.sort.each{|cfnam|
    puts cfnam
  }
}
