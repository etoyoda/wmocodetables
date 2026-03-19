require 'csv'

# 長いテキスト要素を調べておく

stat=Hash.new

Dir.glob('{GRIB2,BUFR4,CCT}/{,notes/}*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  lineno=0
  tab.each{|row|
    lineno+=1
    row.headers.each{|field|
      text=row[field]
      next if text.nil?
      len=text.size
      next if len < 150
      stat[len]=Hash.new unless stat.include?(len)
      loc=[cfnam,lineno,field].join(" ")
      stat[len][loc]=true
    }
  }
}

stat.keys.sort.reverse.each{|lineno|
  ent=stat[lineno]
  loc=ent.keys[0,3].join("\t")
  printf "%5u %5u %s\n", lineno, ent.size, loc
}
