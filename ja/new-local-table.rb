#!/usr/bin/ruby
require 'csv'

def conv fnam
  outfnam=File.basename(fnam)
  unless outfnam.sub!(/_en/,'_ja') then
    outfnam.sub!(/\./, 'ja.')
  end
  warn "making template #{outfnam} <- #{fnam}"
  tab=CSV.read(fnam, headers:true)
  CSV.open(outfnam, 'w', write_headers:true, headers:tab.headers) {|csv|
    emptyp=true
    tab.each{|row|
      if row.any?{|_, value| value=='Reserved for local use'} then
        row['Status']='Replace'
        csv << row
        row['Status']='Local'
        csv << row
        emptyp=false
      end
    }
    if emptyp then
      row=tab.first
      row['Status']='Local'
      csv << row
    end
  }
end

for fnam in ARGV
  conv(fnam)
end
