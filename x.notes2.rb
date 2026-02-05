require 'csv'

# Note_en の

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

Dir.glob('{GRIB2,BUFR4,CCT}/*.csv').each{|cfnam|
  tab=CSV.read(cfnam,headers:true)
  tabsym=csvfnam_to_tabsym(File.basename(cfnam))
  f=tab.headers
  nkey = if f.include?('Note_en') then 'Note_en'
    elsif f.include?('Note') then 'Note'
    else nil
    end
  dkey = case tabsym
    when /^G-T/ then 'Contents_en'
    when /^G-(C42|CF)/ then 'MeaningParameterDescription_en'
    else raise tabsym
    end
  raise unless f.include?(dkey)
  p [tabsym, nkey, dkey]
}
