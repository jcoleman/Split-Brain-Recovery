#!/usr/bin/env ruby

require 'set'
require 'pp'

# TODO: handle DELETE?
# TODO: filter blank rows

# {txid => {ctid => [op, previous_ctids]}}
#
# when fuzzy matching, it's possible that the order of ops is:
# tx 1 insert tup 1 # ignore
# tx 1 commit # ignore
# tx 2 update tup 1
# diverge
# tx 2 commit
# tx 3 update tup 1 # this should probably collapse over tx 2, but maybe doesn't matter because the ctid for tx 2 won't be visible
# tx 3 commit
#
txns = {}
ARGF.each do |line|
  # INSERT:
  # rmgr: Heap        len (rec/tot):    304/   304, tx: 2568340889, lsn: 3583/A8AFCA78, prev 3583/A8AFCA38, desc: INSERT off 28, blkref #0: rel 1663/33128/34868 blk 47499295
  # UPDATE:
  # rmgr: Heap        len (rec/tot):    387/   387, tx: 2568340888, lsn: 3583/A8ABF9E8, prev 3583/A8ABF9B0, desc: UPDATE off 5 xmax 2568340888 ; new off 20 xmax 0, blkref #0: rel 1663/33128/34868 blk 47499612, blkref #1: rel 1663/33128/34868 blk 47499528

  match = line.match(%r{rmgr: Heap .+, tx:\s+(\d+), .+, desc: ([\w\+]+) (.+)})

  unless match
    #$stderr.puts "ignored: #{line}"
    next
  end

  tx, desc, rest = match[1..-1]
  ctids = txns[tx] ||= {}
  case desc
  when 'INSERT+INIT', 'INSERT'
    off, tspace, db, relfilenode, blk = rest.match(%r{off (\d+), blkref #0: rel (\d+)/(\d+)/(\d+) blk (\d+)})[1..-1]
    old_ctid = ctid = [relfilenode, blk, off]

    ctids[ctid] = [desc]
  when 'UPDATE', 'UPDATE+INIT', 'HOT_UPDATE'
    # off 3 xmax 2568340239 ; new off 4 xmax 0, blkref #0: rel 1663/33128/34868 blk 47499581
    old_off, new_off, tspace, db, relfilenode, blk, old_blk_info = rest.match(%r{off (\d+) xmax \d+ .*; new off (\d+) xmax \d+, blkref #0: rel (\d+)/(\d+)/(\d+) blk (\d+)(, .+)?})[1..-1]
    if old_blk_info
      old_tspace, old_db, old_relfilenode, old_blk = old_blk_info.match(%r{blkref #1: rel (\d+)/(\d+)/(\d+) blk (\d+)})[1..-1]
    end
    old_ctid = [old_relfilenode || relfilenode, old_blk || blk, old_off]
    ctid = [relfilenode, blk, new_off]

    old_desc, *ctid_history = ctids.delete(old_ctid)
    ctids[ctid] = [old_desc || desc, ctid_history + ["(#{old_ctid[1..-1].join(',')})"]]
  end
end

# pp txns

puts "txid,relfilenode,block,offset,op,ctid_history"
txns.each do |tx, ctids|
  ctids.each do |ctid, data|
    op, *ctid_history = data
    output = "#{tx},#{ctid.join(",")},#{op}"
    if ctid_history
      output << ",\"#{ctid_history.join("|")}\""
    end
    puts output
  end
end
