require 'csv'
require 'diff/lcs'

  def diff_tables(t1, t2)
    raise 'header mismatch' unless t1.headers==t2.headers
    headers=t1.headers
    a_tokens=t1.map{|r| headers.map{|h| r[h]}}
    b_tokens=t2.map{|r| headers.map{|h| r[h]}}
    sdiff=Diff::LCS.sdiff(a_tokens,b_tokens)
    out=[]
    out << headers.join(',')
    i=j=0
    sdiff.each do |chg|
      case chg.action
      when '='
#        out << "  " + headers.map{|h| t1[i][h].to_s}.join(',')
        i+=1
        j+=1
      when '-'
#        out << "- " + headers.map{|h| t1[i][h].to_s}.join(',')
        out << "- " + t1[i].inspect
        i+=1
      when '+'
#        out << "+ " + headers.map{|h| t2[j][h].to_s}.join(',')
        out << "+ " + t2[j].inspect
        j+=1
      when '!'
#        out << "- " + headers.map{|h| t1[i][h].to_s}.join(',')
#        out << "+ " + headers.map{|h| t2[j][h].to_s}.join(',')
        out << "- " + t1[i].inspect
        out << "+ " + t2[j].inspect
        i+=1
        j+=1
      else raise 'unexpected'
      end
    end
    out.join("\n")
  end

t1=CSV.read('GRIB2/GRIB2_CodeFlag_4_2_0_20_CodeTable_en.csv',headers:true)
t2=CSV.read('GRIB2-FT2026-1/GRIB2_CodeFlag_4_2_0_20_CodeTable_en.csv',headers:true)
puts diff_tables(t1,t2)
