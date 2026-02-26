#!/usr/bin/ruby

require 'csv'

ARGV.each{|arg|
  t=CSV.read(arg,headers:true)
  puts "|==="
  puts "|列名 |名称・用法 "
  t.headers.each{|h| puts "|#{h} | "}
  puts "|==="
}

