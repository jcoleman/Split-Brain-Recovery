#!/usr/bin/env ruby

require 'set'

txids = Set.new
File.open(ARGV[0]).each do |line|
  line.chomp
  txids << line.to_i
end

#header = $stdin.gets
#puts header
$stdin.each do |tuple|
  txid = tuple.match(/^(\d+),/)[1]
  if txids.include?(txid.to_i)
    puts tuple
  end
end
