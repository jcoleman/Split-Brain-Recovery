#!/usr/bin/env ruby

require 'pg'
require 'csv'

$conn = PG::Connection.open(
  :dbname => 'demo',
  :user => 'postgres',
  :port => 5432,
  :host => 'localhost',
)

$relfilenodes = {}
def relfilenode_to_tablename(relfilenode)
  $relfilenodes[relfilenode] ||=
    $conn.exec("select oid::regclass from pg_class where relfilenode = #{relfilenode}").values.first.first
rescue => e
  $stderr.puts "Failed to lookup table for relfilenode: #{relfilenode}\n#{e}"
  nil
end

CSV do |csv_out|
  CSV($stdin, :headers => true) do |csv_in|
    csv_in.each do |row|
      tablename = relfilenode_to_tablename(row["relfilenode"])
      next if tablename.nil? || tablename =~ /^(pgq|pg_)/
      out =[row["txid"], row["relfilenode"], row["block"], row["offset"], row["op"], tablename]
      ctids = row["ctid_history"].split("|") + ["(#{row["block"]},#{row["offset"]})"]
      result = nil
      ctids.reverse.each do |ctid|
        query = "select row_to_json(t) from #{tablename} t where ctid = '#{ctid}'"
        if (result = $conn.exec(query).values.first)
          break
        end
      end

      if result
        out << result.last
      end
      csv_out << out
    end
  end
end
