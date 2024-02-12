require "mechanize"
require "http/client"
require "random"

page = Random.rand(77)

agent = Mechanize.new
page = agent.get("https://konachan.net/post?tags=landscape&page=#{page}")

url = page.css("#post-list-posts li").sample.css("a.directlink")[0]["href"]

r = Random.new
name = r.base64(10)

Dir.children(Dir.current).each do |file|
  File.delete?(file) if file.includes?("==.jpg")
end

HTTP::Client.get url do |response|
  File.open("#{name}.jpg", "w") do |file|
    IO.copy response.body_io, file
  end
end

`automator -i "~/#{name}.jpg" ~/setDesktopPicture.workflow`
