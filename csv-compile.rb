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

  def csvconv csvfnam
    lfirst=true
    bn=File.basename(csvfnam)
    table=CSV.read(csvfnam,headers:true)
    if table.empty?
      raise "empty file #{bn}"
    end
    headers=table.headers
    row1=table.first
    if headers[0]=='Title_en' and headers[1]=='SubTitle_en' then
      @adf.puts "=== file #{bn}: #{row1['Title_en']}"
      @adf.puts "#{row1['SubTitle_en']}"
      @adf.puts
    else
      @adf.puts "=== file #{bn}"
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
