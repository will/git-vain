require 'digest/sha1'

MSG = 'dead'
base = `git cat-file -p HEAD`
counter = 0

while true do
  content = base + counter.to_s + "\n"
  store = "commit #{content.length}\0" + content
  sha1 = Digest::SHA1.hexdigest(store)

  break if sha1[0..3] == MSG

  counter+=1

  puts counter if (counter%100000).zero?
end

puts counter

File.open("/tmp/commit", 'w') {|f| f.write(content) }
sha2=`git hash-object -t commit /tmp/commit`.strip

if sha1==sha2
  system("git reset --soft HEAD^")
  system("git hash-object -t commit -w /tmp/commit")
  system("git reset --soft #{sha1}")
else
  puts "Invalid!"
  puts sha1
  puts sha2
end
