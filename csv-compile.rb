#!/usr/bin/ruby

require 'csv'

class CSVCompileAdoc

  def initialize proj
    @proj=proj
    warn "converting #{@proj}"
    @adf=nil
  end

  def run
    raise unless File.directory?(@proj)
    outfn=@proj.sub(/$/,'-tables.adoc')
    File.open(outfn,'w:UTF-8') do |adf|
      @adf=adf
      preamble
      Dir.glob(File.join(@proj,'*.csv')).sort.each{|csvfnam|
        csvconv(csvfnam)
      }
    end
    warn "asciidoc output: #{outfn}"
  end

  def preamble
    @adf.puts <<PREAMBLE
= #{@proj} に含まれる表
WMO
:toc:

== Tables

PREAMBLE
  end

  def decamel camel
    camel.gsub(/(?<! )([A-Z][a-z]+)/) do
      word=Regexp.last_match(1).to_s
      " #{word}"
    end
  end

  def csvtabname csvfnam
    case csvfnam
    when /^GRIB2_Template_(\d+)_(\d+)_(\w+)_en\.csv$/ then
      sec,tnu,ttyp=$1,$2,$3
      ttyp=decamel(ttyp)
      "GRIB2: #{ttyp} #{sec}.#{tnu}"
    when /^GRIB2_CodeFlag_(\d+)_(\d+)_(Code|Flag)Table_en\.csv$/ then
      sec,tnu,ttyp=$1,$2,$3
      "GRIB2: #{ttyp} Table #{sec}.#{tnu}"
    when /^GRIB2_CodeFlag_4_2_(\d+)_(\d+)_CodeTable_en\.csv$/ then
      disc,categ=$1,$2
      "GRIB2: Code Table 4.2 / product discipline #{disc}, parameter category #{categ}"
    when /^BUFRCREX_TableB_en_(\d+)\.csv$/ then
      cls=$1
      "BUFR4: Table B, Class #{cls}"
    when /^(BUFR|CREX)_Table([AC])_en\.csv$/ then
      cfm,tn=$1,$2
      "BUFR4: #{cfm} Table #{tn}"
    when /^(BUFR|CREX)_TableD_en_(\d+)\.csv$/ then
      cfm,cls=$1,$2
      "BUFR4: #{cfm} Table D, Class #{cls}"
    when /^BUFRCREX_CodeFlag_en_(\d+)\.csv$/ then
      "BUFR4: Class #{format('%02u', $1.to_i)} - BUFR/CREX table entries"
    when /^COV\.csv$/ then
      "CCT: Common Code Tables to Binary and Alphanumeric Codes"
    when /^C(\d+)\.csv$/ then
      tn=$1
      tn=format('%u', tn.to_i)
      "CCT: Common Code Table C-#{tn}"
    else
      raise "unknown file pattern #{csvfnam}"
      csvfnam
    end
  end

  def csvconv csvfnam
    lfirst=true
    bn=File.basename(csvfnam)
    table=CSV.read(csvfnam,headers:true)
    if table.empty?
      raise "empty file #{bn}"
    end
    headers=table.headers
    row1=table.first
    tabname=csvtabname(bn)
    if headers[0]=='Title_en' and headers[1]=='SubTitle_en' then
      @adf.puts "=== #{tabname} - #{row1['Title_en']}"
      @adf.puts "#{row1['SubTitle_en']}"
      @adf.puts
    else
      @adf.puts "=== #{tabname}"
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

for proj in ARGV
  CSVCompileAdoc.new(proj).run
end
