#!/usr/bin/ruby

require 'csv'

class TDCSabun

  class ItiziSaibun

    def initialize ftyp
      @ftyp=ftyp
      @fnams=Hash.new
      @table=[]
      @headers=nil
    end

    def file_add fnam,lang
      @fnams[lang]=fnam
    end

    def find_rbuf rbuf
      @table.size.times{|ofs|
        if @table[ofs,rbuf.size]==rbuf then
          return Range.new(ofs,ofs+rbuf.size-1)
        end
      }
      return nil
    end

    def replace_lbuf selected, lbuf
      selected=Range.new(@table.size,nil) if selected.nil?
      @table[selected]=lbuf
    end

    def patch csvja
      state=:init
      rbuf=[]
      lbuf=[]
      selected=nil
      csvja.each{|row|
        stwd=row['Status']
        myrow=row.dup
        myrow.delete('Status')
        if state==:init and stwd=='Replace' then
          rbuf.push myrow
          state=:r
        elsif state==:init and stwd=='Local' then
          lbuf.push myrow
          state=:l
        elsif state==:r and stwd=='Replace' then
          rbuf.push myrow
        elsif state==:r and stwd=='Local' then
          selected=find_rbuf(rbuf)
          lbuf.push myrow
          state=:l
        elsif state==:l and stwd=='Replace' then
          replace_lbuf(selected,lbuf)
          lbuf=[]
          rbuf=[myrow]
          state=:r
        elsif state==:l and stwd=='Local' then
          lbuf.push myrow
        else
          raise "unsupported Status #{stwd}"
        end
      }
      if state==:l then
        replace_lbuf(selected,lbuf)
      elsif state==:r then
        warn "Replace without Local"
      end
    end

    def build lang
      raise unless @fnams['en']
      csv=CSV.read(@fnams['en'],headers:true)
      csv.each{|row|
        next if 'Extension'==row['Status']
        row.delete('Status')
        @table.push(row)
      }
      @headers=csv.headers
      csv=nil
      if @fnams.include?('ja') then
        csvja=CSV.read(@fnams['ja'],headers:true)
        patch(csvja)
        csvja=nil
      end
    end

  end

  class Revision

    # CSV ファイル名から略号と言語を分類して2要素配列で返す
    def fbunrui fnam
      ftyp=lang=nil
      case File.basename(fnam)
      when /^GRIB2_CodeFlag_(\d)_(\d+)_(Code|Flag)Table_(en|ja)\.csv$/ then
        s,n,cf,lang=$1,$2,$3,$4
        ftyp=format('GC-%01u-%05u-%c',s.to_i,n.to_i,cf[0])
      when /^GRIB2_CodeFlag_4_2_(\d+)_(\d+)_CodeTable_(en|ja)\.csv$/ then
        d,k,lang=$1,$2,$3
        ftyp=format('GC-4-00002-%03u-%05u-C',d.to_i,k.to_i)
      when /^CodeFlag_(notes|table)(ja)?\.csv$/
        ftyp='GC-N'+$1[0].upcase
        lang=$2||'en' 
      when /^GRIB2_Template_(\d)_(\d+)_[A-Za-z]+Template_(en|ja)\.csv$/ then
        s,t,lang=$1,$2,$3
        ftyp=format('GT-%01u-%05u', s, t)
      when /^Template_(notes|table)(ja)?\.csv$/
        ftyp='GT-N'+$1[0].upcase
        lang=$2||'en' 
      end
      [ftyp, lang]
    end

    def initialize dirs
      @cat=Hash.new
      scan_dirs(dirs)
    end

    def scan_dirs(dirs)
      dirs.each{|dir|
        pat=File.join(dir, '{*.csv,notes/*.csv}')
        Dir.glob(pat).each{|fnam|
          ftyp,lang=fbunrui(fnam)
          next unless ftyp
          cat_add(fnam,ftyp,lang)
        }
      }
    end

    def cat_add fnam,ftyp,lang
      @cat[ftyp]=ItiziSaibun.new(ftyp) unless @cat.include?(ftyp)
      @cat[ftyp].file_add(fnam,lang)
    end

    def build lang
      @cat.each{|ftyp,is| is.build(lang) }
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

  def lang
    @cfg[:lang]
  end

  def build
    @db1=Revision.new(@cfg[:d1]).build(lang)
    @db2=Revision.new(@cfg[:d2]).build(lang)
    return self
  end

  def run
  end

end

if $0 == __FILE__
  TDCSabun.new(ARGV).build.run
end
