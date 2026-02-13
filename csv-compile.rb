#!/usr/bin/ruby

require 'csv'

class CSVCompileAdoc

  def initialize argv
    @adfnam='tdcf-tables.adoc'
    @adf=nil
    @projs=[]
    @lang='ja'
    for arg in argv
      case arg
      when /^-o/ then @adfnam=$'
      when /^-l/ then @lang=$'
      else @projs.push arg
      end
    end
    @csvdb=Hash.new
    @notedb=Hash.new
    @dictdb=Hash.new
    @patdb=Hash.new
    @in_adoc_tab=nil
    @fixdb=nil
  end

  def unicode_unescape txt
      txt.gsub(/\\u\{([0-9A-Fa-f\s]+)\}|\\u([0-9A-Fa-f]{4})/) do
        hexes = $1 ? $1.split : [$2]
        hexes.map { |h| h.to_i(16).chr(Encoding::UTF_8) }.join
      end
  end

  def scandir
    load_fixwmo_csv
    for proj in @projs
      warn "scanning #{proj}..."
      Dir.glob(File.join(proj,'*.csv')).sort.each{|csvfnam|
        bn=File.basename(csvfnam)
        @csvdb[csvfnam_to_tabsym(bn)]=csvfnam
      }
      warn "loading #{proj}/notes..."
      Dir.glob(File.join(proj,'notes','*.csv')).each{|nfnam|
        @notedb[nfnam]=CSV.read(nfnam,headers:true)
        apply_fixdb(File.basename(nfnam),@notedb[nfnam])
      }
    end
    load_resources_csv
  end

  def load_resources_csv
    fnam='resources.csv'
    warn "loading #{fnam}..."
    CSV.foreach(fnam,headers:true) do |row|
      next unless row['lang']==@lang
      kwd=row['Keyword']
      txt=unicode_unescape(row['Text'])
      # unicode escapes
      @dictdb[kwd]=txt
      @patdb[Regexp.new(kwd)]=txt if /^\^/===kwd
    end
  end

  def load_fixwmo_csv
    fnam='fixwmo.csv'
    warn "loading #{fnam}..."
    @fixdb=CSV.read(fnam,headers:true)
  end

  def apply_fixdb(bn,table)
    @fixdb.each{|fix|
      next unless fix['csvName']==bn
      table.each{|row|
        next unless row[fix['keyField']]===fix['keyValue']
        tf=fix['targetField']
        next unless row[tf]===fix['ifMatch']
        warn "fix #{bn} #{fix['keyField']}=#{fix['keyValue']} #{tf}:=#{fix['replace']}"
        row[tf]=fix['replace']
      }
    }
  end

  def vizpat tabsym
    @patdb.each{|pat,txt|
      return format(txt,$1.to_i,$2.to_i) if pat===tabsym
    }
    warn "unresolved table name #{tabsym}"
    return tabsym
  end

  def vizkwd keyword
    return @dictdb[keyword] if @dictdb.include?(keyword)
    warn "unresolved keyword #{keyword}"
    return keyword
  end

  def run
    scandir
    File.open(@adfnam,'w:UTF-8') do |adf|
      @adf=adf
      topfnam='toppage-ja.txt'
      File.open(topfnam,'r:UTF-8') { |topf|
        topf.each{|line|
          case line
          when /^#c([34]) \/(.+)\// then
            lev,re=$1,$2
            lev=lev.to_i
            re=Regexp.new(re)
            @csvdb.keys.grep(re).sort.each{|kwd|
              csvconv(kwd,@csvdb[kwd],lev)
            }
          when /^#tn (\S+)/ then
            fn=Hash.new
            arg=$1
            add_table_notes(arg,fn)
            flush_footnotes(fn)
            fn=nil
          else
            @adf.puts line
          end
        }
      }
    end
    warn "asciidoc output: #{@adfnam}"
  end

  def csvfnam_to_tabsym csvfnam
    case csvfnam
    when /^GRIB2_Template_(\d+)_(\d+)_\w+_en\.csv$/ then
      sec,tnu=$1,$2
      format('G-T%u-%05u', sec.to_i, tnu.to_i)
    when /^GRIB2_CodeFlag_(\d+)_(\d+)_(Code|Flag)Table_en\.csv$/ then
      sec,tnu,ttyp=$1,$2,$3
      ttyp.gsub!(/[a-z]/,'')
      format('G-CF%u-%05u-%s', sec.to_i, tnu.to_i, ttyp)
    when /^GRIB2_CodeFlag_4_2_(\d+)_(\d+)_CodeTable_en\.csv$/ then
      disc,categ=$1,$2
      format('G-C42-%02u-%05u', disc.to_i, categ.to_i)
    when /^BUFRCREX_TableB_en_(\d+)\.csv$/ then
      cls=$1
      format('BC-B%02u', cls.to_i)
    when /^(BUFR|CREX)_Table([AC])_en\.csv$/ then
      cfm,tn=$1,$2
      format('%s-%s', cfm[0], tn[0])
    when /^(BUFR|CREX)_TableD_en_(\d+)\.csv$/ then
      cfm,cls=$1,$2
      format('%s-D%02u', cfm[0], cls.to_i)
    when /^BUFRCREX_CodeFlag_en_(\d+)\.csv$/ then
      format('BC-CFT%02u', $1.to_i)
    when /^COV\.csv$/ then
      "COV"
    when /^C(\d+)\.csv$/ then
      tn=$1
      format('CCT-C%02u', tn.to_i)
    else
      raise "unknown file pattern #{csvfnam}"
    end
  end

  def mklink(tabsym,cell,row,footnotes)
    text=cell.to_s.dup
    ret=[]
    if text.sub!(/^\(flags - see /,'') then
      ret.push(['(flags - see ', nil])
    elsif text.sub!(/^ ?\([Ss]ee \t*/,'') then
      ret.push(['(see ', nil])
    elsif text.sub!(/^\((?=[CN])/, '') then
      ret.push(['(see ', nil])
    end
    while not text.empty?
      if text.sub!(/^ and (?!\d)/, '') then
        ret.push([' and ', nil])
      elsif text.sub!(/^Code table (\d)\.(\d+|PTN)/, '') then
        a,sec,tno=$&,$1,$2
        raise :unexpected unless /^G/===tabsym
        #sec,tno=row['codeTable'].split(/\./,2)
        ret.push([a,format("G-CF%u-%05u-C", sec.to_i, tno.to_i)])
      elsif text.sub!(/^Flag table (\d)\.(\d+)/, '') then
        cell,sec,tno=$&,$1,$2
        raise :unexpected unless /^G/===tabsym
        ret.push([cell,format("G-CF%u-%05u-F", sec.to_i, tno.to_i)])
      elsif text.sub!(/^Common Code table  ?C[-\u{2013}](\d+)(?#
      #?)(?: in Part C\/c\.)?/, '') then
        cell,tno=$&,$1
        link=format('CCT-C%02u', tno.to_i)
        ret.push([cell,link])
      elsif text.sub!(/^[Nn]otes? (\d+(?:, \d+)*(?: and \d+)?)/, '') then
        nsymstr=$1
        nsyms=nsymstr.split(/ and |, /)
        ids=(row['noteIDs']||row['NoteID']).to_s.split(/,/)
        ret.push(['Note ',nil])
        nsyms.size.times{|i|
          nsym=nsyms[i]
          if ids[i] then
            linksym="#{tabsym}_n#{ids[i]}"
            footnotes[Integer(nsym)]=linksym
            ret.push([nsym,linksym])
          else
            msg="missing note id for #{nsym} in #{tabsym}"
            # バグ35解決までの暫定処置
            msg+=' (known issue #35)' if /^C/===tabsym
            warn msg
            ret.push([nsym,nil])
          end
          ret.push([', ',nil])
        }
        ret.pop
      elsif text.sub!(/^Note(?=\)| and)/, '') then
        nid=row['noteIDs']
        raise unless /^\d+$/===nid
        linksym="#{tabsym}_n#{nid}"
        footnotes[0]=linksym
        ret.push(['Note', linksym])
      elsif text.sub!(/^\) ?/, '') then
        ret.push([')', nil])
        break
      else
        raise "unsupported Note_en #{text.inspect}"
      end
    end
    ret
  end

  # 現在の表への脚注を保持するハッシュ footnotes に表全体にかかる脚注を追加する
  def add_table_notes tabsym, footnotes
    pkey=pat=nil
    case tabsym
    when /^G-T(\d)-(\d+)/ then
      pkey=format('%u.%u',$1.to_i,$2.to_i)
      pat=/Template_table\.csv$/
    when /^G-CF(\d)-(\d+)/ then
      pkey=format('%u.%u.0.0',$1.to_i,$2.to_i)
      # hack
      pkey='4.2' if /^4\.2\./===pkey
      pat=/CodeFlag_table\.csv$/
    when /^G-C42-(\d+)-(\d+)/ then
      pkey=format('4.2.%u.%u',$1.to_i,$2.to_i)
      pat=/CodeFlag_table\.csv$/
    when /^BC-B(\d+)/ then
      pkey=format('%02u',$1.to_i)
      pat=/BUFRCREX_TableB_table\.csv$/
    when /^B-C/ then
      pkey='BUFR Table C - Data description operators'
      pat=/BUFR_TableC_table\.csv$/
    when /^B-D(\d+)/ then
      pkey=format('%02u',$1.to_i)
      pat=/BUFR_TableD_table\.csv$/
    when /^CCT-C(\d+)/ then
      pkey=format('%02u',$1.to_i)
      pat=/CCT_table\.csv$/
    when /^BC-CFT(\d+)_s(\d)(\d\d)(\d\d\d)/ then
      pkey=format('%01u %02u %03u',$2.to_i,$3.to_i,$4.to_i)
      pat=/BUFRCREX_CodeFlag_table\.csv$/
    else
      return
    end
    tabfn=@notedb.keys.find{|fn| pat===fn}
    @notedb[tabfn].each{|row|
      next unless row.first[1]==pkey
      noteid,notation=row['noteID'],row['notation']
      next if notation.nil? or notation=='n/a'
      linksym="#{tabsym}_n#{noteid}"
      #warn "add_table_notes #{tabsym} #{notation} #{linksym}"
      footnotes[Integer(notation)]=linksym
    }
  end

  def cols_spec tabsym, cols
    case tabsym
    when /^G-T/ then
      return cols.map{|h| if h=='Contents_en' then 4 else 1 end}.join(',')
    when /^G-CF/ then
      return cols.map{|h| if h=='MeaningParameterDescription_en' then 4 else 1 end}.join(',')
    when /^G-C42/ then
      return cols.map{|h| if h=='MeaningParameterDescription_en' then 3 else 1 end}.join(',')
    when /^[BC]-A/ then
      return cols.map{|h| if h=='Meaning_en' then 3 else 1 end}.join(',')
    when /^BC-B/ then
      return cols.map{|h| case h
      when 'FXY' then 4
      when 'ElementName_en' then 9
      else 3 end}.join(',')
    when /^[BC]-C/ then
      return cols.map{|h| case h
      when 'OperatorName_en' then 4
      when 'OperationDefinition_en' then 9
      else 2 end}.join(',')
    when /^[BC]-D/ then
      return cols.map{|h| if h=='ElementName_en' then 3 else 1 end}.join(',')
    when /^BC-CF/ then
      return cols.map{|h| if h=='EntryName_en' then 3 else 1 end}.join(',')
    when /^CCT-C02/ then return "2,1,1,3"
    when /^CCT-C06/ then return "1,3,1,1,1,1"
    when /^CCT-C08/ then return "1,1,3,1,4"
    when /^CCT-C/ then
      return cols.map{|h|
        case h
        when 'Effective date' then 2
        when /_en$/ then 4
        else 1
        end
      }.join(',')
    end
    format('%u',cols.size)
  end

  def emit_section_header level, tabsym, sectl, subtl
    @adf.puts "[[#{tabsym}]]"
    @adf.puts "#{'=' * level} #{sectl}"
    @adf.puts subtl if subtl
    @adf.puts ''
  end

  def begin_table tabsym, cols
    raise 'begin_table in table' if @in_adoc_table
    @in_adoc_table=true
    scols=cols_spec(tabsym,cols)
    @adf.puts "[cols=\"#{scols}\",options=\"header\"]"
    @adf.puts "|==="
    @adf.puts(cols.map{|h| "|#{vizkwd h}"}.join(' '))
  end

  def end_table
    raise 'end_table out of table' if not @in_adoc_table
    @in_adoc_table=false
    @adf.puts "|==="
  end

  TableType=Struct.new(:cols, :modettl, :modeid,
    :modeent, :modeseq, :modestat, :coltg)

  def analyze_headers(table,tabsym)
    headers=table.headers
    tt=TableType.new
    tt.cols=[]
    headers.each {|col|
      case col
      when 'Title_en','SubTitle_en' then
        # Category と Title_en が共存するのでとりあえず Category を優先させる
        tt.modettl=:title unless tt.modettl
      when 'ClassNo','ClassName_en' then
        tt.modettl=:class
      when 'Category','CategoryOfSequences_en' then
        tt.modettl=:categ
      when 'Value','UnitComments_en' then
        emptycol=true
        table.each{|row| emptycol=false if row[col]}
        tt.cols.push col unless emptycol
      when 'Note_en','noteIDs','codeTable','flagTable' then
        raise :unexpected unless headers.include?('Note_en')
        tt.modeid='Note_en'
      when 'Note','NoteID' then
        raise :unexpected unless headers.include?('Note')
        tt.modeid='Note'
      when 'Status' then
        tt.modestat=true
      when 'EntryName_sub1_en','EntryName_sub2_en' then
        tt.modeent='EntryName_en'
      when 'FXY1' then
        tt.modeseq='FXY1'
      when 'UnitType' then
        tt.modeseq='UnitType'
      else
        tt.cols.push col
      end
    }
    if tt.modeid then
      tt.coltg= case tabsym
        when /^G-T/ then 'Contents_en'
        when /^G-(C42|CF)/ then 'MeaningParameterDescription_en'
        when /^(BC-B|[BC]-D)/ then 'ElementName_en'
        when /^BC-CFT/ then 'EntryName_en' 
        when /^[BC]-C/ then 'OperatorName_en'
        when /^CCT-C06/ then 'Meaning'
        else raise "#{tabsym} - #{headers.inspect}"
        end
    end
    if headers.include?('FXY') and headers.include?('ElementName_en') and
    not headers.include?('BUFR_Unit') then
      tt.modeseq='FXY'
      tt.cols.shift(2)
    end
    return tt
  end

  def csvconv kwd, csvfnam, level=4
    bn=File.basename(csvfnam)
    table=CSV.read(csvfnam,headers:true)
    if table.empty?
      raise "empty file #{bn}"
    end
    apply_fixdb(bn,table)
    tabsym=csvfnam_to_tabsym(bn)
    tt=analyze_headers(table,tabsym)
    case tt.modettl
    when :title then
      row1=table.first
      sectl="#{vizpat tabsym} - #{row1['Title_en']}"
      subtl=row1['SubTitle_en']
    when :class then
      row1=table.first
      sectl="#{vizpat tabsym} - Class #{row1['ClassNo']}"
      subtl=row1['ClassName_en']
    when :categ then
      row1=table.first
      sectl="#{vizpat tabsym} - Class #{row1['Category']}"
      subtl=row1['CategoryOfSequences_en']
    else
      sectl=vizpat(tabsym)
      subtl=''
    end
    emit_section_header(level, tabsym, sectl, subtl)
    unless tt.modeseq
      begin_table(tabsym, tt.cols) 
    end
    footnotes=Hash.new
    seqname=nil
    prev_seq=nil
    table.each{|row|
      if tt.modeseq and prev_seq != row[tt.modeseq] then
        seqname="#{tabsym}_s#{row[tt.modeseq].gsub(/\s/,'')}"
        stlkey=if tt.modeseq=='FXY1' then 'Title_en' else 'ElementName_en' end
        seqtl="#{row[tt.modeseq]} #{row[stlkey]}"
        if prev_seq then
          end_table
          flush_footnotes(footnotes) if /^BC-CFT/===tabsym
        end
        add_table_notes(seqname, footnotes)
        emit_section_header(level+1, seqname, seqtl, nil)
        begin_table(seqname, tt.cols)
        prev_seq=row[tt.modeseq]
      end
      vals=[]
      tt.cols.each{|h|
        # 列内容の印字（基本動作）
        vals.push "|#{row[h]}"
        # modeentフラグの注記を付加
        if tt.modeent==h then
          ['EntryName_sub1_en','EntryName_sub2_en'].each{|k|
            vals.push " (#{row[k]})" if row[k]
          }
        end
        if tt.coltg==h then
          ts=tabsym
          ts=seqname if seqname and /^BC-CFT/===tabsym
          link=mklink(ts,row[tt.modeid],row,footnotes)
          if link then
            vals.push(' ')
            link.each{|k,v|
              vals.push(if v then "<<#{v},#{k}>>" else k end)
            }
          end
        end

      }
      @adf.puts vals.join
    }
    end_table
    add_table_notes(tabsym, footnotes)
    flush_footnotes(footnotes)
  end
  
  def flush_footnotes(footnotes)
    unless footnotes.empty? then
      @adf.puts ''
      @adf.puts "#{vizkwd 'Note_en'}:"
      footnotes.keys.sort.each{|notenum|
        text=footnotes[notenum]
        rtext=note_resolve(text)
        midasi=if notenum.zero? then '' else format('%u/ ', notenum) end
        @adf.puts ''
        @adf.puts "[[#{text}]]#{midasi}#{rtext}"
      }
    end
    footnotes.clear
    @adf.puts ''
  end

  # 与えられたkeyに対応する注記テキストを検索して返す、入口メソッド
  def note_resolve key
    rule = NOTE_RULES.find {|r| r.match?(key) }
    return unknown_note_key(key) unless rule
    tag, file_re, nid = rule.extract(key)
    fetch_note(tag, file_re, nid)
  end

  # 注記テキストの探索先ファイル情報を保持する構造体
  NoteRule = Struct.new(:tag, :key_re, :nid_group, :file_re) do
    def match?(key)
      key_re.match?(key)
    end
    # 構造体の主要3要素を配列で返す
    def extract(key)
      m=key_re.match(key)
      [tag, file_re, m[nid_group]]
    end
  end

  # 注記テキストの探索先ファイル情報
  NOTE_RULES=[
    NoteRule.new("G-CF", /^G-(?:CF\d-\d+-[CF]|C42-\d+-\d+)_n(\d+)/, 1,
    /CodeFlag_notes\.csv$/),
    NoteRule.new("G-T", /^G-T\d-\d+_n(\d+)/, 1,
    /Template_notes\.csv$/),
    NoteRule.new("BC-B", /^BC-B\d+_n(\d+)/, 1,
    /BUFRCREX_TableB_notes\.csv$/),
    NoteRule.new("B-C", /^B-C_n(\d+)/, 1,
    /BUFR_TableC_notes\.csv$/),
    NoteRule.new("B-D", /^B-D\d+(?:_s\d+)?_n(\d+)/, 1,
    /BUFR_TableD_notes\.csv$/),
    NoteRule.new("BC-CFT", /^BC-CFT\d+(?:_s\d+)?_n(\d+)/, 1,
    /BUFRCREX_CodeFlag_notes\.csv$/),
    NoteRule.new("CCT-C", /^CCT-C\d+_n(\d+)/, 1,
    /CCT_notes\.csv$/)
  ]

  def fetch_note tag, file_re, nid
    fn=note_file(file_re) or raise "{missing note file for #{tag}}"
    row=@notedb[fn].find {|r| r["noteID"]==nid}
    if row.nil? then
      warn(msg="{missing #{tag} noteID #{nid}}")
      return msg
    end
    row["note"]
  end

  # @notedb のキーのうち、指定した正規表現にマッチするファイル名を1つ選び、
  # キャッシュして返す
  def note_file file_re
    @note_file_cache ||= {}
    @note_file_cache[file_re] ||= @notedb.keys.find{|fnam| file_re===fnam}
  end

  # 検索に失敗した場合にkeyそのものを返すフォールバック、この際メッセージを出す
  def unknown_note_key key
    warn "unknown note key #{key}"
    key
  end

end

CSVCompileAdoc.new(ARGV).run
