#!/usr/bin/ruby

require 'csv'

class CSVCompileAdoc

  def initialize argv
    @adfnam='tdcf-tables.adoc'
    @adf=nil
    @projs=[]
    for arg in argv
      case arg
      when /^-o/ then @adfnam=$'
      else @projs.push arg
      end
    end
    @csvdb=Hash.new
  end

  def scandir
    for proj in @projs
      warn "scanning #{proj}..."
      Dir.glob(File.join(proj,'*.csv')).sort.each{|csvfnam|
        bn=File.basename(csvfnam)
        @csvdb[csvtabname(bn)]=csvfnam
      }
    end
  end

  def run
    scandir
    File.open(@adfnam,'w:UTF-8') do |adf|
      @adf=adf
      adoc_preamble
      @adf.puts "== FM92 GRIB第2版 付表"
      @adf.puts "=== 第1節のテンプレート"
      @csvdb.keys.grep(/^G-IT/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== 第3節のテンプレート"
      @csvdb.keys.grep(/^G-GDT/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== 第4節のテンプレート"
      @csvdb.keys.grep(/^G-PDT/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== 第5節のテンプレート"
      @csvdb.keys.grep(/^G-DRT/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== 第7節のテンプレート"
      @csvdb.keys.grep(/^G-DT/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== 第1節の符号表およびフラグ表"
      @csvdb.keys.grep(/^G-[CF]T1/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== 第3節の符号表およびフラグ表"
      @csvdb.keys.grep(/^G-[CF]T3/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== 第4節の符号表およびフラグ表"
      @csvdb.keys.grep(/^G-[CF]T4/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== 第5節の符号表およびフラグ表"
      @csvdb.keys.grep(/^G-[CF]T5/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== 第6節の符号表およびフラグ表"
      @csvdb.keys.grep(/^G-[CF]T6/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "== FM94 BUFR 付表"
      @adf.puts "=== BUFR表A"
      @csvdb.keys.grep(/^B-A/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== BUFR/CREX表B"
      @csvdb.keys.grep(/^BC-/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== BUFR表C"
      @csvdb.keys.grep(/^B-C/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== BUFR表D"
      @csvdb.keys.grep(/^B-D/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "== FM95 CREX 付表"
      @adf.puts "=== CREX表A"
      @csvdb.keys.grep(/^C-A/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== CREX表C"
      @csvdb.keys.grep(/^C-C/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "=== CREX表D"
      @csvdb.keys.grep(/^C-D/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],4)}
      @adf.puts "== 共通符号表"
      @csvdb.keys.grep(/^CCT-/).sort.each{|kwd| csvconv(kwd,@csvdb[kwd],3)}
    end
    warn "asciidoc output: #{@adfnam}"
  end

  def adoc_preamble
    @adf.puts <<PREAMBLE
= 国際気象通報式 付表
:toc:

PREAMBLE
  end

  def csvtabname csvfnam
    case csvfnam
    when /^GRIB2_Template_(\d+)_(\d+)_(\w+)_en\.csv$/ then
      sec,tnu,ttyp=$1,$2,$3
      ttyp.gsub!(/[a-z]/,'')
      format('G-%s%u.%05u', ttyp, sec.to_i, tnu.to_i)
    when /^GRIB2_CodeFlag_(\d+)_(\d+)_((Code|Flag)Table)_en\.csv$/ then
      sec,tnu,ttyp=$1,$2,$3
      ttyp.gsub!(/[a-z]/,'')
      format('G-%s%u.%05u', ttyp, sec.to_i, tnu.to_i)
    when /^GRIB2_CodeFlag_4_2_(\d+)_(\d+)_CodeTable_en\.csv$/ then
      disc,categ=$1,$2
      format('G-CT4.2.%02u.%05u', disc.to_i, categ.to_i)
    when /^BUFRCREX_TableB_en_(\d+)\.csv$/ then
      cls=$1
      format('BC-B%03u', cls.to_i)
    when /^(BUFR|CREX)_Table([AC])_en\.csv$/ then
      cfm,tn=$1,$2
      format('%s-%s', cfm[0], tn[0])
    when /^(BUFR|CREX)_TableD_en_(\d+)\.csv$/ then
      cfm,cls=$1,$2
      format('%s-D%03u', cfm[0], cls.to_i)
    when /^BUFRCREX_CodeFlag_en_(\d+)\.csv$/ then
      format('BC-CFT%02u', $1.to_i)
    when /^COV\.csv$/ then
      "COV"
    when /^C(\d+)\.csv$/ then
      tn=$1
      format('CCT-C%02u', tn.to_i)
    else
      raise "unknown file pattern #{csvfnam}"
      csvfnam
    end
  end

  def csvconv kwd, csvfnam, level=4
    lfirst=true
    bn=File.basename(csvfnam)
    table=CSV.read(csvfnam,headers:true)
    if table.empty?
      raise "empty file #{bn}"
    end
    tabhead=('=' * level)
    headers=table.headers
    row1=table.first
    tabname=csvtabname(bn)
    if headers[0]=='Title_en' and headers[1]=='SubTitle_en' then
      @adf.puts "#{tabhead} #{tabname} - #{row1['Title_en']}"
      @adf.puts "#{row1['SubTitle_en']}"
      @adf.puts
    else
      @adf.puts "#{tabhead} #{tabname}"
    end
    cols=headers.reject{|h| h=='Title_en' or h=='SubTitle_en'}
    @adf.puts '[options="header"]'
    @adf.puts '|==='
    @adf.puts(cols.map{|h| "|#{h}"}.join(' '))
    table.each{|row|
      vals=cols.map{|h| "|#{row[h]}"}
      @adf.puts vals
    }
    @adf.puts '|==='
    @adf.puts ''
  end

end

CSVCompileAdoc.new(ARGV).run
