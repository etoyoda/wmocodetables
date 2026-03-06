#!/usr/bin/ruby

class TDCSabun

  class Revision

    def fbunrui fnam
      ft=lang=nil
      case File.basename(fnam)
      when /^GRIB2_CodeFlag_(\d)_(\d+)_(Code|Flag)Table_(en|ja).csv$/ then
        s,n,cf,lang=$1,$2,$3,$4
        ft=format('G-CF%01u-%05u-%s',s.to_i,n.to_i,cf)
      end
      [ft, lang]
    end

    def initialize dirs
      @db=Hash.new
      dirs.each{|dir|
        pat=File.join(dir, '{*.csv,notes/*.csv}')
        Dir.glob(pat).each{|fnam|
          ft,lang=fbunrui(fnam)
          p(lang,ft) if ft
        }
      }
    end

  end

  def initialize argv
    @db1=@db2=nil
    @cfg={:lang=>'ja', :suffix=>nil, :d1=>[], :d2=>[]}
    argv.each{|arg|
      case arg
      when /^-lang[=:](ja|en)$/ then @cfg[:lang]=$1
      when /^-s/ then @cfg[:suffix]=$'
      when /^-/ then raise "unknown option #{arg}"
      else @cfg[:suffix]=arg
      end
    }
    init_dirs
  end

  def init_dirs
    gbc=%w(GRIB2 BUFR4 CCT)
    @cfg[:d1]=gbc
    sfx=@cfg[:suffix]
    raise "ruby #$0 suffix" unless sfx
    @cfg[:d2]=gbc.map{|d| d+sfx}
  end

  def build
    @db1=Revision.new(@cfg[:d1])
    @db2=Revision.new(@cfg[:d2])
    return self
  end

  def run
  end

end

if $0 == __FILE__
  TDCSabun.new(ARGV).build.run
end
