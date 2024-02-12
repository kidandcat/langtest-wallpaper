require 'net/http'

n = rand(77)
body = Net::HTTP.get(URI("https://konachan.net/post?tags=landscape&page=#{n}"))

# Get all image urls
image_urls = body.scan(/https:\/\/konachan\.net\/image\/.*?\.jpg/)

# Remove previous images
Dir.glob('*.jpg').each { |f| File.delete(f) }

# Get the image
image = Net::HTTP.get(URI(image_urls.sample))

# Save the image
name = SecureRandom.hex(5)
File.open("#{name}.jpg", 'w') { |f| f.write(image) }

# Set the wallpaper
system "automator", "-i", "~/#{name}.jpg", "/Users/jairo/setDesktopPicture.workflow"