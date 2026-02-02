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
  end

  def scandir
    for proj in @projs
      warn "scanning #{proj}..."
      Dir.glob(File.join(proj,'*.csv')).sort.each{|csvfnam|
        bn=File.basename(csvfnam)
        @csvdb[csvtabname(bn)]=csvfnam
      }
      warn "loading #{proj}/notes..."
      Dir.glob(File.join(proj,'notes','*.csv')).each{|nfnam|
        @notedb[nfnam]=CSV.read(nfnam,headers:true)
      }
    end
    fnam='resources.csv'
    warn "loading #{fnam}..."
    CSV.foreach(fnam,headers:true) do |row|
      next unless row['lang']==@lang
      kwd=row['Keyword']
      txt=row['Text']
      @dictdb[kwd]=txt
      @patdb[Regexp.new(kwd)]=txt if /^\^/===kwd
    end
  end

  def vizpat tabname
    @patdb.each{|pat,txt|
      return format(txt,$1.to_i,$2.to_i) if pat===tabname
    }
    warn "unresolved table name #{tabname}"
    return tabname
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
          else
            @adf.puts line
          end
        }
      }
    end
    warn "asciidoc output: #{@adfnam}"
  end

  def csvtabname csvfnam
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

  def mklink(tabname,cell,row,footnotes)
    if /^4\.\d+$/===row['noteIDs'] and row['codeTable'].nil? then
      row['codeTable']=row['noteIDs']
      row['noteIDs']=nil
    end
    if /^\(see/===row['noteIDs'] and row['Note_en'].nil? then
      row['Note_en']=row['noteIDs']
      row['noteIDs']=nil
    end
    if row['noteIDs'] then
      links=[]
      ids=row['noteIDs'].split(/,/)
      cell=cell.dup
      cell='(see Note 1)' if cell=='(see Note)'
      cell='(see Note 1)' if cell=="(see Note and Code table 4.4)"
      cell.gsub!(/ and /,',')
      unless /[nN]otes? (\d+(, ?\d+)*)/ === cell
        raise "bn1 #{row.inspect}"
      end
      nids=$1.split(/, ?/)
      raise "bn2 #{ids.inspect} #{nids.inspect}" unless ids.size == nids.size
      ids.size.times{|i|
        text=nids[i]
        aid="#{tabname}_n#{ids[i]}"
        footnotes[text]=aid
        links.push([aid,text])
      }
      links.first.last.sub!(/^/,'(see Note ')
      links.last.last.sub!(/$/,')')
      links
    elsif row['codeTable'] then
      raise :unexpected unless /^G/===tabname
      sec,tno=row['codeTable'].split(/\./,2)
      [[format("G-CF%u-%05u-C", sec.to_i, tno.to_i),cell]]
    elsif row['flagTable'] then
      raise :unexpected unless /^G/===tabname
      sec,tno=row['flagTable'].split(/\./,2)
      [[format("G-CF%u-%05u-F", sec.to_i, tno.to_i),cell]]
    else
      nil
    end
  end

  def table_header level, tabname, sectl, subtl, cols
    @adf.puts "[[#{tabname}]]"
    @adf.puts "#{'=' * level} #{sectl}"
    @adf.puts subtl if subtl
    @adf.puts ''
    return if cols.nil?
    @adf.puts "[cols=\"#{cols.size}\",options=\"header\"]"
    @adf.puts "|==="
    @adf.puts(cols.map{|h| "|#{vizkwd h}"}.join(' '))
  end

  def csvconv kwd, csvfnam, level=4
    bn=File.basename(csvfnam)
    table=CSV.read(csvfnam,headers:true)
    if table.empty?
      raise "empty file #{bn}"
    end
    tabname=csvtabname(bn)
    headers=table.headers
    cols=[]
    modettl=modeid=modestat=modeent=modeseq=nil
    headers.each {|col|
      case col
      when 'Title_en','SubTitle_en' then
        # Category と Title_en が共存するのでとりあえず Category を優先させる
        modettl=:title unless modettl
      when 'ClassNo','ClassName_en' then
        modettl=:class
      when 'Category','CategoryOfSequences_en' then
        modettl=:categ
      when 'Value','UnitComments_en' then
        emptycol=true
        table.each{|row| emptycol=false unless row[col].to_s.empty?}
        cols.push col unless emptycol
      when 'noteIDs','codeTable','flagTable' then
        raise :unexpected unless headers.include?('Note_en')
        modeid='Note_en'
      when 'Status' then
        modestat=true
      when 'EntryName_sub1_en','EntryName_sub2_en' then
        modeent='EntryName_en'
      when 'FXY1' then
        modeseq='FXY1'
      else
        cols.push col
      end
    }
    if headers.include?('FXY') and headers.include?('ElementName_en') and
    not headers.include?('BUFR_Unit') then
      modeseq='FXY'
      cols.shift(2)
    end
    case modettl
    when :title then
      row1=table.first
      sectl="#{vizpat tabname} - #{row1['Title_en']}"
      subtl=row1['SubTitle_en']
    when :class then
      row1=table.first
      sectl="#{vizpat tabname} - Class #{row1['ClassNo']}"
      subtl=row1['ClassName_en']
    when :categ then
      row1=table.first
      sectl="#{vizpat tabname} - Class #{row1['Category']}"
      subtl=row1['CategoryOfSequences_en']
    else
      sectl=vizpat(tabname)
      subtl=''
    end
    if modeseq
      table_header(level, tabname, sectl, subtl, nil)
    else
      table_header(level, tabname, sectl, subtl, cols)
    end
    footnotes=Hash.new
    prev_seq=nil
    table.each{|row|
      if modeseq and prev_seq != row[modeseq] then
        seqname="#{tabname}_s#{row[modeseq]}"
        stlkey=if modeseq=='FXY1' then 'Title_en' else 'ElementName_en' end
        seqtl="#{row[modeseq]} #{row[stlkey]}"
        @adf.puts "|===" if prev_seq
        table_header(level+1, seqname, seqtl, nil, cols)
        prev_seq=row[modeseq]
      end
      vals=[]
      cols.each{|h|
        if modeid==h then
          link=mklink(tabname,row[h],row,footnotes)
        else
          link=nil
        end
        if link then
          vals.push '|'
          link.each{|k,v| vals.push "<<#{k},#{v}>>" }
        else
          vals.push "|#{row[h]}"
          if modeent==h then
            ['EntryName_sub1_en','EntryName_sub2_en'].each{|k|
              vals.push " (#{row[k]})" if row[k]
            }
          end
        end
      }
      @adf.puts vals.join
    }
    @adf.puts '|==='
    unless footnotes.empty? then
      @adf.puts ''
      @adf.puts '注:'
      footnotes.keys.sort.each{|notenum|
        text=footnotes[notenum]
        rtext=note_resolve(text)
        @adf.puts ''
        @adf.puts "[[#{text}]]#{notenum}: #{rtext}"
      }
    end
    @adf.puts ''
  end

  def note_resolve key
    rule = NOTE_RULES.find {|r| r.match?(key) }
    return unknown_note_key(key) unless rule
    tag, file_re, nid = rule.extract(key)
    fetch_note(tag, file_re, nid)
  end

  NoteRule = Struct.new(:tag, :key_re, :nid_group, :file_re) do
    def match?(key)
      key_re.match?(key)
    end
    def extract(key)
      m=key_re.match(key)
      [tag, file_re, m[nid_group]]
    end
  end

  NOTE_RULES=[
    NoteRule.new("G-CF", /^G-(?:CF\d-\d+-[CF]|C42-\d+-\d+)_n(\d+)/, 1,
    /GRIB.*\/CodeFlag_notes\.csv$/),
    NoteRule.new("G-T", /^G-T\d-\d+_n(\d+)/, 1,
    /GRIB.*\/Template_notes\.csv$/),
    NoteRule.new("BC-B", /^BC-B\d+_n(\d+)/, 1,
    /BUFR.*\/BUFRCREX_TableB_notes\.csv$/),
    NoteRule.new("B-C", /^B-C_n(\d+)/, 1,
    /BUFR.*\/BUFR_TableC_notes\.csv$/),
    NoteRule.new("B-D", /^B-D\d+_n(\d+)/, 1,
    /BUFR.*\/BUFR_TableD_notes\.csv$/),
    NoteRule.new("BC-CFT", /^BC-CFT\d+_n(\d+)/, 1,
    /BUFR.*\/BUFRCREX_CodeFlag_notes\.csv$/),
  ]

  def fetch_note tag, file_re, nid
    fn=note_file(file_re) or raise "{missing note file for #{tag}}"
    row=@notedb[fn].find {|r| r["noteID"]==nid}
    return "{missing #{tag} noteID #{nid}}" if row.nil?
    row["note"]
  end

  def note_file file_re
    @note_file_cache ||= {}
    @note_file_cache[file_re] ||= @notedb.keys.find{|fnam| file_re===fnam}
  end

  def unknown_note_key key
    warn "unknown note key #{key}"
    key
  end

end

CSVCompileAdoc.new(ARGV).run
