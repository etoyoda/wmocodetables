#!/usr/bin/ruby

class TDCSabun

  class Revision
  end

  def initialize argv
    @dirs_a = []
    @dirs_b = []
    @lang='ja'
    @suffix = nil
    argv.each{|arg|
      case arg
      when /^-lang[=:](ja|en)$/ then @lang=$1
      when /^-/ then raise "unknown option #{arg}"
      else @suffix=arg
      end
    }
    init_dirs
  end

  def init_dirs
  end

  def build
    return self
  end

  def run
  end

end

if $0 == __FILE__
  TDCSabun.new(ARGV).build.run
end
