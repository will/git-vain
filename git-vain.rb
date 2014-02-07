#!/usr/bin/env ruby

require 'digest/sha1'

def get_message
  pattern = /\A[a-f0-9]{2,10}\z/
  if ARGV.first && ARGV.first =~ pattern
    msg = ARGV.first
  else
    msg = `git config vain.default`.chomp
  end

  unless msg =~ pattern
    abort "ERROR: vain.default not set, or not lowercase hex\nhint: git config --global vain.default <hex>"
  end
  msg
end

def parse_commit
  original = `git cat-file -p HEAD`
  parts = original.split(/(^author.*> |committer.*> )(\d+)(.*$)/, 3)
  [ parts[0..1].join,
    parts[2   ].to_i,
    parts[3..5].join,
    parts[6   ].to_i,
    parts[7..-1].join ]
end

def format_progress(ad, cd, hashes, rewrite="\r")
  print "∆author: %5d, ∆committer: %5d, khash: %d#{rewrite}" % [ad,cd,hashes/1000]
end

def spiral_pair(n)
  # http://2000clicks.com/mathhelp/CountingRationalsSquareSpiral1.aspx
  s = ((Math.sqrt(n)+1)/2).to_i
  l = ((n-((2*s)-1)**2)/(2*s)).to_i
  e = (n-((2*s)-1)**2)-(2*s*l)-s+1

  case l
  when 0 then [s,  e]
  when 1 then [-e, s]
  when 2 then [-s,-e]
  else        [e, -s]
  end
end

def spiral(max_side)
  total = (max_side*2+1)**2-1
  (1..total).lazy.map {|n| spiral_pair(n) }
end


def search(message, parsed_commit)
  puts "searching for: #{message}"
  head, orig_auth_t, middle, orig_comm_t, rest = parsed_commit
  counter = 0

  spiral(3600).each do |(ad,cd)|
    new_auth_t = orig_auth_t + ad
    new_comm_t = orig_comm_t + cd

    content = [head, new_auth_t, middle, new_comm_t, rest].join
    store = "commit #{content.length}\0" + content
    sha1 = Digest::SHA1.hexdigest(store)

    if sha1.start_with?(message)
      format_progress(ad,cd,counter,"\n")
      return [content,sha1]
    end

    counter += 1
    format_progress(ad,cd,counter) if (counter%100000).zero?
  end
end

content, sha1 = search(get_message, parse_commit)

if ARGV.include? "--dry-run"
  puts sha1
  exit
end

File.open("/tmp/commit", 'w') {|f| f.write(content) }
sha2=`git hash-object -t commit /tmp/commit`.strip

if sha1==sha2
  system("git reset --soft HEAD^")
  system("git hash-object -t commit -w /tmp/commit")
  system("git reset --soft #{sha1}")
else
  puts "failed, git doesn't agree:"
  puts sha1
  puts sha2
  exit 1
end

