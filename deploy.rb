#!/usr/bin/ruby

def prompt(default, *args)
  print(*args)
  result = gets.strip
  result.empty? ? default : result
end

def runBash(command)
  IO.popen(command) do |output| 
      while line = output.gets do
        puts line
      end
  end
end

(destination, username, password) = ARGV

pull_image = false #TODO i

destination = prompt("cococloud.co", "Destination?") unless destination
username = prompt("admin", "Database username?") unless username
password = prompt("", "Database password for #{username}?") unless password

docker_commands = %Q(
docker kill couchdb
docker rm couchdb
#{"docker pull klaemo/couchdb" if pull_image}
docker run -d -p 80:5984 --name couchdb klaemo/couchdb
)

docker_commands = docker_commands.split(/\n/).reject! { |c| c.empty? }.map{ |command|
  "sudo #{command}"
}.join(";")

command = "
STARTPOINT=\`pwd\`
ssh -t #{destination} \"#{docker_commands}\"
"

puts "Connecting to #{destination} to do the docker install"
puts command
puts "Enter your password to gain sudo access on #{destination}"
runBash command

tries = 0

loop do
  break if `curl --silent http://#{destination}`.match(/Welcome/) or (tries+=1) > 10
  print "."
  sleep 1
end

destination_with_credentials = "http://#{username}:#{password}@#{destination}"

coconut_directory = "/tmp/coconut-git"

command2 = "

echo 'Creating admin user'
curl -X PUT http://#{destination}/_config/admins/#{username} -d '\"#{password}\"'

echo 'Turning on CORS'
curl -# -X PUT #{destination_with_credentials}/_config/httpd/enable_cors -d '\"true\"'
curl -# -X PUT #{destination_with_credentials}/_config/cors/origins -d '\"*\"'
curl -# -X PUT #{destination_with_credentials}/_config/cors/credentials -d '\"true\"'
curl -# -X PUT #{destination_with_credentials}/_config/cors/methods -d '\"GET, PUT, POST, HEAD, DELETE\"'
curl -# -X PUT #{destination_with_credentials}/_config/cors/headers -d '\"accept, authorization, content-type, origin, referer, x-csrf-token\"'


rm -rf #{coconut_directory}
mkdir -p #{coconut_directory}
cd #{coconut_directory}
git clone --single-branch https://github.com/ICTatRTI/coconut-mobile.git
git clone --single-branch https://github.com/ICTatRTI/coconut-cloud.git
git clone --single-branch https://github.com/ICTatRTI/coconut-factory.git

echo \"{}\" > #{coconut_directory}/coconut-mobile/.couchapprc
echo \"{}\" > #{coconut_directory}/coconut-cloud/.couchapprc
echo \"{}\" > #{coconut_directory}/coconut-factory/.couchapprc

echo \"Create a file with default connection info.\"
echo \'{\"cloud\": \"#{destination}\", \"cloud_credentials\": \"#{username}:#{password}\"}\' > #{coconut_directory}/coconut-mobile/_attachments/defaults.json


echo 'Creating mobile'
cd #{coconut_directory}/coconut-mobile/_attachments
gulp
couchapp push --docid _design/couchapp #{destination_with_credentials}/coconut-mobile&

echo 'Creating cloud'
cd #{coconut_directory}/coconut-cloud
gulp
couchapp push --docid _design/coconut #{destination_with_credentials}/coconut-factory

echo 'Creating factory'
cd #{coconut_directory}/coconut-factory
couchapp push --docid _design/couchapp #{destination_with_credentials}/coconut-factory

#echo 'Creating user #{username}'
#curl -# -X PUT #{destination_with_credentials}coconut-factory/admin -d '{\"user\":\"#{username},#{password}\"}'

echo 'Creating rewrites to make http://mobile.#{destination} work without specifying the design document.'
curl -# -X PUT #{destination_with_credentials}/_config/vhosts/mobile.#{destination} -d '\"coconut-mobile/_design/couchapp/_rewrite\"'
curl -# -X PUT #{destination_with_credentials}/_config/vhosts/mobile -d '\"coconut-mobile/_design/couchapp/_rewrite\"'

# This doesn't work because paths to other databases get rewritten
#echo 'Creating rewrites to make http://factory.#{destination} work without specifying the design document.'
#curl -# -X PUT #{destination_with_credentials}/_config/vhosts/factory.#{destination} -d '\"coconut-factory/_design/couchapp/_rewrite\"'
#curl -# -X PUT #{destination_with_credentials}/_config/vhosts/factory -d '\"coconut-factory/_design/couchapp/_rewrite\"'

cd $STARTPOINT
"

runBash command2

domains_resolve = true
domains = "mobile,factory"
domains.split(/,/).each do |domain|
  puts "Checking to see if the #{domain} resolves..."
  result = `ping -c 1 #{domain}.#{destination} | awk -F'[()]' '/PING/{print $2}'`
  puts result
  domains_resolve = false if result.match(/unknown host/)
puts "#{domains} look good" if domains_resolve
end
if destination == "localhost" and not domains_resolve
  puts "You can add this to your /etc/hosts file to make the domains resolve to your local instance\n\n"
  domains.split(/,/).each do |domain|
    puts "127.0.0.1   #{domain}.#{destination}"
  end
end

puts "\n\n\n"
puts "DONE. Here are the URLs to start using Coconut:\n"
puts "Coconut Factory, for creating new Coconut Applications: http://factory.#{destination}/coconut-factory/_design/couchapp"
puts "Coconut Mobile, to install an offline capable version of Coconut for data collection: http://mobile.#{destination}/"
