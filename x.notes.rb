require 'csv'

PAT=%r{^ ?\((flags - )?([Ss]ee \t*)?(( and )?((Code|Flag) table \d\.(\d+|PTN)|Common Code table  ?C[-\u{2013}]\d+( in Part C\/c\.)?|Note|[Nn]otes? \d+(, \d+)*( and \d+)?))+\)? ?$}

Dir.glob('{GRIB2,BUFR4,CCT}/*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  next unless tab.headers.include?('Note_en')
  puts cfnam
  tab.each{|row|
    next unless row['Note_en']
    text=row['Note_en']
    raise text unless PAT===text
    puts text.inspect
  }
}
