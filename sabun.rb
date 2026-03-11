#!/usr/bin/ruby

require 'csv'

# WMOが提供するTDCF CSV表の差分を asciidoc 文書に成形出力するプログラム
class TDCSabun

  class ResourceData

    def initialize
      @fix=CSV.read('fixwmo.csv',headers:true)
      @res=CSV.read('resources.csv',headers:true)
      @tnt=nil
    end

    def fix_csvrow basename, row
      @fix.each{|f|
        next unless basename==f['csvName']
        next unless row[f['keyField']]==f['keyValue']
        next unless row[f['targetField']]==f['ifMatch']
        warn "do_fix #{row[f['targetField']]}=#{f['replace']}"
        row[f['targetField']]=f['replace']
      }
    end

    def build lang
      @tnt=Hash.new
      @res.each{|row|
        next unless /^^/===row['Keyword']
        next unless lang===row['lang']
        re=Regexp.new(row['Keyword'])
        @tnt[re]=row['Text']
      }
    end

    def sectitle ftyp
      @tnt.each{|re,txt|
        return format(txt,$1.to_i,$2.to_i) if re===ftyp
      }
      return ftyp
    end

  end

  # 一次細分表を表現するクラス。
  # 通報式の表番号が複数CSVで分割されていることがあり、その数だけ構築される。
  class ItiziSaibun

    # ItiziSaibun.new
    # 構築：略号 ftyp と訂正パッチ fix を与える
    def initialize ftyp,resd
      @ftyp,@resd=ftyp,resd
      @fnams=Hash.new
      @table=[]
      @headers=nil
    end

    # CSVファイルを読み込み対象に登録する。言語 lang 別に複数ファイルを登録できる。
    def file_add fnam,lang
      @fnams[lang]=fnam
    end

    #--- Itizisaibun#build() から呼ばれるサブルーチン
    
    # 置換対象行群 rbuf を探す
    def find_rbuf rbuf
      @table.size.times{|ofs|
        if @table[ofs,rbuf.size]==rbuf then
          return Range.new(ofs,ofs+rbuf.size-1)
        end
      }
      return nil
    end

    # 置換を実施する
    def replace_lbuf selected, lbuf
      selected=Range.new(@table.size,nil) if selected.nil?
      @table[selected]=lbuf
    end

    # 読み込み済みの英語版データに言語パッチファイル（CSV::Table)を適用する
    # 状態遷移機械は process.adoc に記載
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

    # 言語 lang を指定してファイルを読み込み表データを構築する。
    def build lang
      fnam_en=@fnams['en']
      raise "missing en file #{@fnams.inspect}" unless fnam_en
      csv=CSV.read(fnam_en,headers:true)
      basename_en=File.basename(fnam_en)
      csv.each{|row|
        next if 'Extension'==row['Status']
        @resd.fix_csvrow(basename_en,row)
        row.delete('Status')
        @table.push(row)
      }
      @headers=csv.headers
      csv=nil
    # lang='en' の場合は英語版を読み込み訂正パッチをあてるだけ。
      return if lang=='en'
    # 他言語の場合は言語パッチファイルがあれば読み込み適用する。
      if @fnams.include?(lang) then
        csvja=CSV.read(@fnams[lang],headers:true)
        patch(csvja)
        csvja=nil
      end
    end

    def csvconv lev
      levmark='='*lev
      sectl=@resd.sectitle(@ftyp)
      puts "#{levmark} #{sectl}" unless 'cclist'==@ftyp
    end

  end

  class Revision

    # CSV ファイル名から略号と言語を分類して2要素配列で返す
    def bunrui_csvname fnam
      ftyp=lang=nil
      case File.basename(fnam)
      when /^GRIB2_CodeFlag_(\d)_(\d+)_(Code|Flag)Table_(en|ja)\.csv$/ then
        s,n,cf,lang=$1,$2,$3,$4
        ftyp=format('Gc-%01u-%05u-%c',s.to_i,n.to_i,cf[0])
      when /^GRIB2_CodeFlag_4_2_(\d+)_(\d+)_CodeTable_(en|ja)\.csv$/ then
        d,k,lang=$1,$2,$3
        ftyp=format('Gc-4-00002-%03u-%05u-C',d.to_i,k.to_i)
      when /^CodeFlag_(notes|table)(ja)?\.csv$/
        ftyp='Gc-N'+$1[0].upcase
        lang=$2||'en' 
      when /^GRIB2_Template_(\d)_(\d+)_[A-Za-z]+Template_(en|ja)\.csv$/ then
        s,t,lang=$1,$2,$3
        ftyp=format('GT-%01u-%05u', s, t)
      when /^Template_(notes|table)(ja)?\.csv$/
        ftyp='GT-N'+$1[0].upcase
        lang=$2||'en' 
      when /^BUFRCREX_TableB_(en|ja)_(\d+)\.csv$/
        lang,klass=$1,$2
        ftyp=format('bB-%02u', klass.to_i)
      when /^(BUFR|CREX)_Table(A|C)_(en|ja)\.csv$/
        cfm,tn,lang=$1,$2,$3
        ftyp=format('%c%c', cfm[0].downcase, tn)
      when /^(BUFR|CREX)_TableD_(en|ja)_(\d+)\.csv$/
        cfm,lang,klass=$1,$2,$3
        ftyp=format('%cD-%02u', cfm[0].downcase, klass.to_i)
      when /^BUFRCREX_CodeFlag_(en|ja)_(\d+)\.csv$/
        lang,klass=$1,$2
        ftyp=format('bF-%02u', klass.to_i)
      when /^BUFRCREX_TableB_(notes|table)(ja)?\.csv$/
        ttyp=$1
        lang=$2||'en'
        ftyp=format('bB-N%c', ttyp[0].upcase)
      when /^(BUFR|CREX)_Table(C|D)_(notes|table)(ja)?\.csv$/
        cfm,tn,ttyp=$1,$2,$3
        lang=$4||'en'
        ftyp=format('%c%c-N%c', cfm[0].downcase, tn, ttyp[0].upcase)
      when /^BUFRCREX_CodeFlag_(notes|table)(ja)?\.csv$/
        ttyp=$1
        lang=$2||'en'
        ftyp=format('bF-N%c', ttyp[0].upcase)
      when /^COV(ja)?\.csv$/
        lang=$1||'en'
        ftyp='cclist'
      when /^C(\d\d)(ja)?\.csv$/
        klass=$1
        lang=$2||'en'
        ftyp=format('cct-%02u', klass.to_i)
      when /^CCT_(notes|table)(ja)?\.csv$/
        ttyp=$1
        lang=$2||'en'
        ftyp=format('cct-N%c', ttyp[0].upcase)
      when /^acronyms\.csv$/
        lang,ftyp='en','A'
      else
        warn "unknown CSV file #{fnam}"
      end
      [ftyp, lang]
    end

    # Revision.new
    def initialize dirs
      @cat=Hash.new
      @resd=ResourceData.new
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
      @cat[ftyp]=ItiziSaibun.new(ftyp,@resd) unless @cat.include?(ftyp)
      @cat[ftyp].file_add(fnam,lang)
    end

    def build lang
      @resd.build(lang)
      @cat.each{|ftyp,is| is.build(lang) }
      self
    end

    def itizi_saibun_list
      @cat.keys
    end

    def select re
      target=@cat.keys.grep(re).grep_v(/-N/)
      target.sort.each{|ftyp|
        yield @cat[ftyp]
      }
    end

  end

  def parse_arg arg
    case arg
    when /^--lang[=:](ja|en)$/ then @cfg[:lang]=$1
    when /^(--out|-o)[=:]/ then @cfg[:out]=$'
    when /^--(tpl|template)[=:]/ then @cfg[:tpl]=$'
    when /^--/ then throw(:help, "unknown option #{arg}")
    else
      arg='' if arg=='HEAD'
      if @cfg[:suf2] then
        throw(:help, "more than two revisions")
      elsif @cfg[:suf1] then
        @cfg[:suf2] = arg
      else
        @cfg[:suf1] = arg
      end
    end
  end

  def init_dirs
    gbc=%w(GRIB2 BUFR4 CCT)
    throw(:help, "rev1 undefined") unless @cfg[:suf1]
    @cfg[:d1]=gbc.map{|d| d+@cfg[:suf1]}
    @cfg[:d2]=gbc.map{|d| d+@cfg[:suf2]} if @cfg[:suf2]
    unless @cfg[:out]
      @cfg[:out]=if @cfg[:suf2]
        then 'tdcf-diff.adoc'
        else 'tdcf-tables.adoc'
        end
    end
  end

  # TDCSabun.new
  def initialize argv
    @db1=@db2=nil
    @cfg={:lang=>'ja', :suf1=>nil, :suf2=>nil, :d1=>[], :d2=>[],
      :out=>nil, :tpl=>'template-ja.txt' }
    helpmsg=catch(:help) {
      argv.each{|arg| parse_arg(arg) }
      init_dirs
      nil
    }
    if helpmsg then
      warn <<HELP
Error: #{helpmsg}
Usage: ruby #$0 [--lang=ja] rev1 [rev2]
rev: HEAD | suffix of dirname
HELP
      exit 16
    end
  end

  def lang
    @cfg[:lang]
  end

  def single_mode?
    not @cfg[:suf2]
  end

  def build
    @db1=Revision.new(@cfg[:d1]).build(lang)
    @db2=Revision.new(@cfg[:d2]).build(lang) unless single_mode?
    return self
  end

  # TENTATIVE
  def compare is, ii1, ii2
    printf("%-25s %s %s\n", is, ii1, ii2)
  end

  def open_output
    warn "output to #{@cfg[:out]}"
    $stdout=File.open(@cfg[:out],'w:UTF-8')
  end

  def filter_file ifp
    ifp.each{|line|
      case line
      when /^#c(3|4) \/(\S+)\//
        lev,re=$1,$2
        lev=lev.to_i
        re=Regexp.new(re)
        @db1.select(re){|is|
          is.csvconv(lev)
        }
      else
        puts(line)
      end
    }
  end

  def run
    open_output
    if single_mode? then
      File.open(@cfg[:tpl],'r:UTF-8'){|ifp|
        filter_file(ifp)
      }
    else
      is1=@db1.itizi_saibun_list
      is2=@db2.itizi_saibun_list
      ismerge=(is1+is2).uniq.sort
      ismerge.each{|is|
        compare is, is1.include?(is), is2.include?(is)
      }
    end
  end

end

if $0 == __FILE__
  TDCSabun.new(ARGV).build.run
end
