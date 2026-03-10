#!/usr/bin/ruby

require 'csv'

class TDCSabun

  class ItiziSaibun

    def initialize ftyp,fix
      @ftyp=ftyp
      @fix=fix
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
          raise "text not found" if selected.nil?
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

    def do_fix basename, row
      @fix.each{|f|
        next unless basename==f['csvName']
        next unless row[f['keyField']]==f['keyValue']
        next unless row[f['targetField']]==f['ifMatch']
        warn "do_fix #{row[f['targetField']]}=#{f['replace']}"
        row[f['targetField']]=f['replace']
      }
    end

    def build lang
      enfnam=@fnams['en']
      raise unless enfnam
      csv=CSV.read(enfnam,headers:true)
      enbn=File.basename(enfnam)
      csv.each{|row|
        next if 'Extension'==row['Status']
        do_fix(enbn,row)
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
    def bunrui_csvname fnam
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
      when /^BUFRCREX_TableB_(en|ja)_(\d+)\.csv$/
        lang,klass=$1,$2
        ftyp=format('BB-%02u', klass.to_i)
      when /^(BUFR|CREX)_Table(A|C)_(en|ja)\.csv$/
        cfm,tn,lang=$1,$2,$3
        ftyp=format('B%c', cfm[0])
      when /^(BUFR|CREX)_TableD_(en|ja)_(\d+)\.csv$/
        cfm,lang,klass=$1,$2,$3
        ftyp=format('B%c-%02u', cfm[0], klass.to_i)
      when /^BUFRCREX_CodeFlag_(en|ja)_(\d+)\.csv$/
        lang,klass=$1,$2
        ftyp=format('BF-%02u', klass.to_i)
      when /^BUFRCREX_TableB_(notes|table)(ja)?\.csv$/
        ttyp=$1
        lang=$2||'en'
        ftyp=format('BB-N%c', ttyp[0])
      when /^BUFR_Table(C|D)_(notes|table)(ja)?\.csv$/
        tn,ttyp=$1,$2
        lang=$3||'en'
        ftyp=format('B%c-N%c', tn, ttyp[0])
      when /^BUFRCREX_CodeFlag_(notes|table)(ja)?\.csv$/
        ttyp=$1
        lang=$2||'en'
        ftyp=format('BF-N%c', ttyp[0])
      when /^COV(ja)?\.csv$/
        lang=$1||'en'
        ftyp='COV'
      when /^C(\d\d)(ja)?\.csv$/
        klass=$1
        lang=$2||'en'
        ftyp=format('CCT-%02u', klass.to_i)
      when /^CCT_(notes|table)(ja)?\.csv$/
        ttyp=$1
        lang=$2||'en'
        ftyp=format('CCT-N%c', ttyp[0])
      when /^acronyms\.csv$/
        lang,ftyp='en','A'
      else
        warn "unknown CSV file #{fnam}"
      end
      [ftyp, lang]
    end

    def initialize dirs,fix
      @cat=Hash.new
      @fix=fix
      warn "= Revision.new(#{dirs.inspect})"
      scan_dirs(dirs)
    end

    def scan_dirs(dirs)
      dirs.each{|dir|
        pat=File.join(dir, '{*.csv,notes/*.csv}')
        Dir.glob(pat).each{|fnam|
          ftyp,lang=bunrui_csvname(fnam)
          next unless ftyp
          cat_add(fnam,ftyp,lang)
        }
      }
    end

    def cat_add fnam,ftyp,lang
      @cat[ftyp]=ItiziSaibun.new(ftyp,@fix) unless @cat.include?(ftyp)
      @cat[ftyp].file_add(fnam,lang)
    end

    def build lang
      @cat.each{|ftyp,is| is.build(lang) }
    end

  end

  def initialize argv
    @db1=@db2=nil
    @cfg={:lang=>'ja', :suffix=>nil, :d1=>[], :d2=>[] }
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
    fix=CSV.read('fixwmo.csv',headers:true)
    @db1=Revision.new(@cfg[:d1],fix).build(lang)
    @db2=Revision.new(@cfg[:d2],fix).build(lang)
    return self
  end

  def run
  end

end

if $0 == __FILE__
  TDCSabun.new(ARGV).build.run
end
