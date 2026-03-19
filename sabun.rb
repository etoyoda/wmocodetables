#!/usr/bin/ruby

require 'csv'
require 'diff/lcs'

# WMOが提供するTDCF CSV表の差分を asciidoc 文書に成形出力するプログラム
class TDCSabun

  # WMOの誤字を訂正するパッチと、表名・列名多言語化リソースを管理
  class ResourceData

    # ResourceData.new
    def initialize
      # 訂正パッチ
      @fix=CSV.read('fixwmo.csv',headers:true)
      # リソースファイル
      @res=CSV.read('resources.csv',headers:true)
      # 表名変換表
      @tnt=nil
      # 列名変換表
      @coln=nil
    end

    # CSV::Row 型の row に訂正パッチをあてる
    def fix_csvrow basename, row
      @fix.each{|f|
        next unless basename==f['csvName']
        next unless row[f['keyField']]==f['keyValue']
        next unless row[f['targetField']]==f['ifMatch']
        warn "do_fix #{row[f['targetField']]}=#{f['replace']}" if $VERBOSE
        row[f['targetField']]=f['replace']
      }
    end

    # 列名の置換、未定義ならCSV上の列名 h そのもの
    def colname h
      @coln[h] or h
    end
    alias :xlate :colname

    # 多言語リソースの言語を選択する
    def build lang
      # 行頭が ^ のものは表名変換表 @tnt に
      @tnt=Hash.new
      @res.each{|row|
        next unless /^\^/===row['Keyword']
        next unless lang===row['lang']
        re=Regexp.new(row['Keyword'])
        @tnt[re]=row['Text']
      }
      # 行頭が ^ でないものは列名変換表 @coln に
      @coln=Hash.new
      @res.each{|row|
        next unless /^^/===row['Keyword']
        next unless lang===row['lang']
        @coln[row['Keyword']]=row['Text']
      }
    end

    # 一次細分表記号 ftyp から指定言語の節見出し文字列を返す
    def sectitle ftyp
      @tnt.each{|re,txt|
        return format(txt,$1.to_i,$2.to_i) if re===ftyp
      }
      return ftyp
    end

  end # class ResourceData

  class NoteDB

    def initialize ftyp, nn, nt
      @ftyp,@nn,@nt=ftyp,nn,nt
      @db=Hash.new
      @cat=Hash.new
      nn.each{|row|
        @cat[row['noteID']]=row['note']
      }
      @merged=nil
    end

    def prepare_nizi nzid_list, mergep
      if mergep then
        h=Hash.new
        nzid_list.each{|nzid| @db[nzid]=h }
        @merged=nzid_list.last
      else
        nzid_list.each{|nzid| @db[nzid]=Hash.new }
      end
    end

    def end_build
      @db.keys.each{|nzid|
        oldhash=@db[nzid]
        newhash=Hash.new
        oldhash.keys.sort.each{|inote|
          newhash[inote]=oldhash[inote]
        }
        @db[nzid]=newhash
      }
    end

    NPAT=/[Nn]otes?(?: (\d+(?:, \d+)*(?: and \d+)?))?/

    def parse_note nzid, row
      note=row['Note_en']||row['Note']
      nids=row['noteIDs']||row['NoteID']
      return if note.nil? or nids.nil?
      return unless NPAT===note
      nxs=$1
      nxs=if nxs then nxs.split(/, | and /) else [nil] end
      raise "noteIDs=#{nids.inspect}" unless /^\d+[a-z]*(?:,\d+[a-z]*)*$/===nids
      nids=nids.split(/,/)
      warn "pn #{[@ftyp,note,nids,nxs].inspect}" if $DEBUG
      if nids.size!=nxs.size
        msg="size mismatch #{@ftyp} Note_en #{nxs.size} != noteIDs #{nids.size}"
        raise msg
      end
      nxs.size.times{|i|
        register_note nzid,nxs[i],nids[i]
      }
    end

    def register_note nzid,notation,nid
      db2=@db[nzid]
      inote=notation.to_i
      if db2[inote] and db2[inote]!=nid
        msg="conflict #{@ftyp} #{inote} #{db2[inote]}<=#{nid}"
        warn msg
      end
      unless @cat.include?(nid)
        msg="missing #{@ftyp} note #{nid}"
        warn msg
        @cat[nid]="(dummy text #{nid})"
      end
      db2[inote]=nid
    rescue NoMethodError =>e
      warn @ftyp.inspect
      warn nzid.inspect
      warn @db.inspect
      raise e
    end

    def tablenotes(nzid,nskey,nsval)
      @nt.each{|row|
        next if nskey and nsval != row[nskey]
        nid=row['noteID']
        notation=row['notation']
        next unless nid
        register_note nzid, notation, nid
      }
    end

    def text_notes(nzid)
      return nil if @merged and @merged != nzid
      return nil if @db[nzid].nil?
      r=[]
      case @db[nzid].size
      when 0 then
        return nil
      when 1 then
        r.push "Note:"
      else
        r.push "Notes:"
      end
      r.push ""
      @db[nzid].keys.each{|inote|
        nid=@db[nzid][inote]
        r.push "#{inote}:" unless inote==0
        r.push @cat[nid]
        r.push ""
      }
      r
    end

    def show_notes(nzid)
      buf=text_notes(nzid)
      puts buf if buf
    end

  end # class NoteDB

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
      @nizis=nil
      @tt=nil
      @footnotes=nil
    end

    attr_reader :ftyp

    # CSVファイルを読み込み対象に登録する。
    # 言語 lang 別に複数ファイルを登録できる。
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
      # not en 言語の言語パッチファイルがあれば読み込み適用する。
      if lang!='en' then
        if @fnams.include?(lang) then
          csvja=CSV.read(@fnams[lang],headers:true)
          patch(csvja)
          csvja=nil
        end
      end
      # 後方参照
      build_nizis
      analyze_headers
    end

  # 二次細分関係ツール

    # 一次細分内で二次細分の分別に用いる列名、一次=二次ならnil
    def nizikey
      case @ftyp
      when /^Gc-4-00001/ then 'SubTitle_en'
      when /^[bc]D-\d/ then 'FXY1'
      when /^bF-\d/ then 'FXY'
      when /^cct-06/ then 'UnitType'
      else nil
      end
    end

    # 二次細分識別子にふさわしくない列値を置換する
    def mangle_nzid str
      case str
      when /^Product discipline (\d+)/ then
        format('%03u', $1.to_i)
      else
        str.gsub(/\W+/, '')[0..16]
      end
    end

    # 二次細分のリスト。非分割の場合はnilを要素とする長さ1の配列
    def build_nizis
      nk=nizikey()
      if nk then
        @nizis=@table.map{|r| mangle_nzid(r[nk])}.uniq.sort
      else
        @nizis=[nil]
      end
    end

    # 二次細分に属する行の配列。非分割の場合はすべての行を返す
    def select_nizi nzid
      nk=nizikey()
      if nk then
        @table.select{|r| nzid==mangle_nzid(r[nk])}
      else
        @table
      end
    end

    # 二次細分記号を登場順に呼び出す
    # 非分割の場合はnilが一回yieldされる
    def each_nizi
      raise "build before each_nizi" unless @nizis
      @nizis.each{|nzid|
        yield(nzid,select_nizi(nzid))
      }
    end

    def each_nizi_pure
      @nizis.each{|nzid| yield(nzid)}
    end

    def nzid_list
      @nizis
    end

    def nzid_last
      @nizis.last
    end

    # 表注釈CSV内で二次細分を分別する列名と値
    def each_nizi2
      case @ftyp
      when /-N/ then "skip note fles"
      when /^GT-(\d)-(\d+)/ then
        yield(nil, 'templateNo', format('%u.%u', $1.to_i, $2.to_i))
      when /^Gc-4-00001-[CF]/ then
        each_nizi_pure{|nzid|
          yield(nzid, 'tableNo', format('4.1.%u.0', nzid.to_i))
        }
      when /^Gc-(\d)-(\d+)-[CF]/ then
        yield(nil, 'tableNo', format('%u.%u.0.0', $1.to_i, $2.to_i))
      when /^Gc-(\d)-(\d+)-(\d+)-(\d+)/ then
        yield(nil, 'tableNo',
          format('%u.%u.%u.%u', $1.to_i, $2.to_i, $3.to_i, $4.to_i))
      when /^(?:b[BD]|cct)-(\d+)/ then
        # last nizi-saibun only
        yield(nzid_last, 'tableNo', format('%02u', $1.to_i))
      when /^bC$/ then
        yield(nil, nil, nil)
      when /^bF-\d/ then
        each_nizi_pure{|nzid|
          raise @ftyp.inspect if nzid.nil?
          f_xx_yyy=format('%s %s %s', nzid[0], nzid[1..2], nzid[3..-1])
          yield(nzid, 'tableNo', f_xx_yyy)
        }
      else
        "do nothing otherwise"
      end
    end

    def each
      @table.each{|row| yield(row)}
    end

    # 表示用解析結果
    TableType=Struct.new(:cols, # 表示対象列
      :title_add, # 節標題に付加すべき列名
      :note, # 注記文の列名
      :note_target, # 注記文を追加すべき列名
      :ent_merge # BUFR符号表の列名統合フラグ
      )
    
    # ヘッダ列を解析して表示対象列と特殊処理フラグを設定する
    def analyze_headers
      @tt=TableType.new
      @tt.cols=[]
      @headers.each{|h|
        case h
        when 'Title_en','SubTitle_en' then @tt.title_add='Title_en'
        when 'ClassNo','ClassName_en' then @tt.title_add='ClassNo'
        when 'Category','CategoryOfSequences_en' then
          @tt.title_add='Category'
        when 'Note_en','Note' then @tt.note=h
        when 'Value','UnitComments_en' then
          @tt.cols.push(h) if @table.any?{|r| r[h]}
        when 'NoteID','noteIDs','codeTable','flagTable' then # do nothing
        when 'EntryName_sub1_en','EntryName_sub2_en' then
          @tt.ent_merge='EntryName_en'
        when nizikey() then # do nothing
        when 'ElementName_en' then
          @tt.cols.push(h) unless /^bF/===@ftyp
        else
          @tt.cols.push(h)
        end
      }
      if @tt.note then
        @tt.note_target=case @ftyp
          when /^GT/ then 'Contents_en'
          when /^Gc/ then 'MeaningParameterDescription_en'
          when /^[bc][BD]/ then 'ElementName_en'
          when /^bF/ then 'EntryName_en'
          when /^[bc]C/ then 'OperatorName_en'
          when /^cct-06/ then 'Meaning'
          else raise @ftyp
          end
      end
    end

    def compile_notes nn, nt
      return if nn.nil? or nt.nil?
      @footnotes=NoteDB.new(ftyp,nn,nt)
      mergep=true if /^(cct-06|bD)/===ftyp
      @footnotes.prepare_nizi(nzid_list, mergep)
      each_nizi{|nzid,table|
        table.each{|row|
          @footnotes.parse_note(nzid,row)
        }
      }
      each_nizi2{|nzid,nskey,nsval|
        @footnotes.tablenotes(nzid,nskey,nsval)
      }
      @footnotes.end_build
    end

  # build より後に実行すべき処理

    # 節標題の表示
    def emit_section_header lev, tabsym, sectl, subtl
      puts "[[#{tabsym}]]"
      puts "#{'=' * lev} #{sectl}"
      puts subtl if subtl
      puts ''
    end

    def nizi_section_header nzid,table,lev
      ssym=[@ftyp, '_s', nzid.gsub(/ /,'')].join
      stlkey=if 'FXY1'==nizikey() then 'Title_en' else 'ElementName_en' end
      tfirst=table.first
      sectl=[tfirst[nizikey()], tfirst[stlkey]].join(' ')
      emit_section_header(lev,ssym,sectl,nil)
    end

    def cols_spec cols
      case @ftyp
      when /^GT/ then
        cols.map{|h| 'Contents_en'==h ? 4 : 1}.join(',')
      when /^Gc/ then
        cols.map{|h| 'MeaningParameterDescription_en'==h ? 4 : 1}.join(',')
      when /^[bc]A/ then
        cols.map{|h| 'Meaning_en'==h ? 3 : 1}.join(',')
      when /^bB/ then
        cols.map{|h| case h
        when 'FXY' then 4
        when 'ElementName_en' then 9
        else 3 end }.join(',')
      when /^bC/ then
        cols.map{|h| case h
        when 'OperatorName_en' then 3
        when 'OperatorDeefinition_en' then 9
        else 2 end }.join(',')
      when /^[bc]D/ then
        cols.map{|h| 'ElementName_en'==h ? 3 : 1}.join(',')
      when /^bF/ then
        cols.map{|h| 'EntryName_en'==h ? 3 : 1}.join(',')
      when /^cct-02/ then
        cols.map{|h| case h
        when 'DateOfAssignment_en' then 2
        when 'RadiosondeSoundingSystemUsed_en' then 5
        else 1 end }.join(',')
      when /^cct-06/ then
        cols.map{|h| 'Meaning'==h ? 3 : 1}.join(',')
      when /^cct-08/ then
        cols.map{|h| case h
        when 'Type_en' then 3
        when 'InstrumentLongName_en' then 4
        else 1 end }.join(',')
      when /^cct/ then
        cols.map{|h| case h
        when 'Effective date' then 2
        when /_en$/ then 4
        else 1 end }.join(',')
      else
        format('%u', cols.size)
      end
    end

    # 二次細分 nzid, table の表本体をを表示する
    def show_rows nzid, table, lev
      nizi_section_header(nzid,table,lev+1) if nzid
      emptyp=true
      buf=[]
      cols=@tt.cols
      scols=cols_spec(cols)
      buf.push "[cols=\"#{scols}\",option=\"header\"]\n"
      buf.push "|===\n"
      cols_d=cols.map{|h| @resd.colname(h)}
      buf.push('|'+cols_d.join(' |')+"\n")
      table.each{|row|
        vv=cols.map{|h|
          txt=row[h]
          txt.gsub!(/\|/, '\|') if txt
          txt="`#{txt}`" if txt and /^(IA5-ASCII|ITA2)$/===h
          txt.sub!(/$/, ' ') if 'conventional'===h
          if @tt.ent_merge==h then
            ['EntryName_sub1_en','EntryName_sub2_en'].each{|k|
              n=row[k]
              txt+=n if n
            }
          end
          if @tt.note_target==h then
            n=row[@tt.note]
            txt=[txt, ' ', n].join if n
          end
          txt
        }
        emptyp=false if not vv.all?{|cell| cell.nil?}
        buf.push('|'+vv.join(' |')+"\n")
      }
      buf.push("|===\n")
      puts buf unless emptyp
    end

    def itizi_section_header lev, addp=nil
      sectl=@resd.sectitle(@ftyp)
      subtl=nil
      tfirst=@table.first
      case @tt.title_add
      when 'Title_en' then
        sectl += " - #{tfirst[@tt.title_add]}"
        subtl = tfirst['SubTitle_en']
      when 'ClassNo' then
        sectl += " - Class #{tfirst[@tt.title_add]}"
        subtl = tfirst['ClassName_en']
      when 'Category' then
        sectl += " - Class #{tfirst[@tt.title_add]}"
        subtl = tfirst['CategoryOfSequences_en']
      end
      sectl=format(@resd.xlate("(new) %s"), sectl) if addp
      emit_section_header(lev,@ftyp,sectl,subtl) unless 'cclist'==@ftyp
      puts @resd.xlate("*Add following*:") if addp
    end

    # 一次細分を表示する。lev は節見出しレベル
    def csvconv lev, addp=nil
      itizi_section_header(lev, addp)
      each_nizi{|nzid,table|
        show_rows(nzid,table,lev)
        @footnotes.show_notes(nzid) if @footnotes
      }
    end

    def headers
      @headers
    end

    def text_notes(nzid)
      return nil unless @footnotes
      @footnotes.text_notes(nzid)
    end

  end # class ItiziSaibun

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

    # 一次細分カタログ@catにCSVファイル名を登録する
    def cat_add fnam,ftyp,lang
      @cat[ftyp]=ItiziSaibun.new(ftyp,@resd) unless @cat.include?(ftyp)
      @cat[ftyp].file_add(fnam,lang)
    end

    # ディレクトリを探索してCSVファイルを一次細分で分類する
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

    # Revision.new
    # CSVファイル一覧を探索してデータ構造を決めるところまで
    def initialize dirs, resd
      @resd=resd
      @cat=Hash.new
      warn "= Revision.new(#{dirs.inspect})"
      scan_dirs(dirs)
    end

    def sectitle ftyp
      @resd.sectitle(ftyp)
    end

    def find_note ftyp
      return [nil,nil] if /^(A|cclist)/===ftyp
      nntyp=ftyp.sub(/(-.*)?$/, '-NN')
      nttyp=ftyp.sub(/(-.*)?$/, '-NT')
      [@cat[nntyp], @cat[nttyp]]
    end

    # CSVデータを読み込むところまで
    def build lang
      @resd.build(lang)
      @cat.each{|ftyp,is| is.build(lang) }
      @cat.each{|ftyp,is|
        is.compile_notes(*find_note(ftyp))
      }
      self
    end

    # 一次細分のリストを返す
    def itizi_saibun_list
      @cat.keys
    end

    # 正規表現 re にマッチする一次細分を順にyieldする
    def select re
      target=@cat.keys.grep(re).grep_v(/-N/)
      target.sort.each{|ftyp|
        yield @cat[ftyp]
      }
    end

    def [] is
      @cat[is]
    end

  end # class Revision

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
  # コマンドライン引数の解析まで
  def initialize argv
    @db1=@db2=@resd=nil
    @cfg={:lang=>'ja', :suf1=>nil, :suf2=>nil, :d1=>[], :d2=>[],
      :out=>nil, :tpl=>'template-ja.txt' }
    @chapter=""
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

  # コマンドラインで指定された言語
  def lang
    @cfg[:lang]
  end

  # コマンドライン引数でリビジョンが1つしか与えられなかった場合に真
  def single_mode?
    not @cfg[:suf2]
  end

  # 各CSV表の読み込み
  def build
    @resd=ResourceData.new
    @db1=Revision.new(@cfg[:d1],@resd).build(lang)
    @db2=Revision.new(@cfg[:d2],@resd).build(lang) unless single_mode?
    return self
  end

  def xlate str
    @resd.xlate(str)
  end

  def open_output
    warn "output to #{@cfg[:out]}"
    $stdout=File.open(@cfg[:out],'w:UTF-8')
  end

  def filter_template_file ifp
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

  def make_full_doc
    File.open(@cfg[:tpl],'r:UTF-8'){|ifp|
      filter_template_file(ifp)
    }
  end

  def self.row_pack row
    row.map{|k,v| "#{k}\t#{v}"}.join("\n")
  end

  def self.row_unpack text
    pairs=text.lines.map{|line|
      k,v=line.chomp.split("\t",2)
      [k,v]
    }
    CSV::Row.new(pairs.map(&:first),pairs.map(&:last))
  end

  def diff_itizi(is)
    emptyp=true
    istab1=@db1[is]
    istab2=@db2[is]
    # in most cases istab2 returns expected results.
    nzids=(istab2.nzid_list+istab1.nzid_list).uniq
    nzids.each{|nzid|
      rows1=istab1.select_nizi(nzid).map{|row| TDCSabun.row_pack(row)}
      rows2=istab2.select_nizi(nzid).map{|row| TDCSabun.row_pack(row)}
      diff=Diff::LCS.diff(rows1,rows2)
      if not diff.empty? then
        if emptyp then
          chapter_mark(is)
          puts "=== #{@db2.sectitle(is)}"
          emptyp=false
        end
        diff.each{|hunk|
          rows_del=hunk.map{|chg|
            if chg.action=='-' then TDCSabun.row_unpack(chg.element) else nil end
          }.compact
          rows_add=hunk.map{|chg|
            if chg.action=='+' then TDCSabun.row_unpack(chg.element) else nil end
          }.compact
          if not rows_del.empty? then
            puts xlate("*Delete following*:")
            istab1.show_rows(nzid,rows_del,3)
          end
          if not rows_add.empty? then
            puts xlate("*Add following*:")
            istab2.show_rows(nzid,rows_add,3)
          end
        }
      end
      rows1=istab1.text_notes(nzid)
      rows2=istab2.text_notes(nzid)
      if rows1 and rows2 then
        diff=Diff::LCS.diff(rows1,rows2)
      else
        diff=[]
      end
      diff.each{|hunk|
        rows_del=hunk.map{|chg|
          if chg.action=='-' then chg.element else nil end
        }.compact
        rows_add=hunk.map{|chg|
          if chg.action=='+' then chg.element else nil end
        }.compact
        if not rows_del.empty? then
          puts xlate("*Delete following*:")
          puts ""
          puts rows_del
        end
        if not rows_add.empty? then
          puts xlate("*Add following*:")
          puts ""
          puts rows_add
        end
      }
    }
  end

  def chapter_mark is
    if /^G/===is and 'G'>@chapter then
      puts "<<<"
      puts "== FM92 GRIB"
    elsif /^b/===is and 'b'>@chapter then
      puts "<<<"
      puts "== FM94 BUFR"
    elsif /^c[A-D]/===is and 'cA'>@chapter then
      puts "<<<"
      puts "== FM95 CREX"
    elsif /^cct/===is and 'cct'>@chapter then
      puts "<<<"
      puts "== Common Code Table"
    end
    @chapter=is
  end

  def compare is, ii1, ii2
    warn sprintf("%-25s %s %s\n", is, ii1, ii2) if $DEBUG
    tabname=@db2.sectitle(is)
    if ii1 and ii2 then
      diff_itizi(is)
    elsif ii2 then
      chapter_mark(is)
      istab2=@db2[is]
      istab2.csvconv(3,:add)
    else
      chapter_mark(is)
      puts format(xlate("=== (delete) %s"), tabname)
      puts format(xlate("*Delete* %s."), tabname)
    end
  end

  def make_diff_doc
    puts xlate("= Changes to TDCF Tables")
    puts ":toc:"
    puts ""
    is1=@db1.itizi_saibun_list
    is2=@db2.itizi_saibun_list
    ismerge=(is2+is1).uniq.sort
    ismerge.each{|is|
      next if /-N/===is
      compare(is, is1.include?(is), is2.include?(is))
    }
  end

  def run
    open_output
    if single_mode? then
      make_full_doc
    else
      make_diff_doc
    end
  end

end

if $0 == __FILE__
  TDCSabun.new(ARGV).build.run
end
