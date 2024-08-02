# frozen_string_literal: true

require 'http'

API_KEY = 'Sr0WJWYFECjCIRU7VUJIDakBkNh1U8FVv4fPvinQeA' # replace with a valid api key
BASE_URL = 'http://mac-m1.local:2283' # replace as needed

require 'optimist'

opts = Optimist.options do
  opt :albumn_id, 'Address of Google Refine'
end

Optimist.die :albumn_id, ':albumn_id' if opts[:albumn_id]

puts opts

def get_assets(album_id)
  payload = {
    "albumId": album_id
  }
  url = "#{BASE_URL}/api/download/info"
  resp = HTTP.headers(:accept => 'application/json', 'x-api-key' => API_KEY).post(url, json: payload).body
  JSON.parse(resp)
end

def download_asset(asset_id)
  url = '/api/download/archive'

  resp = HTTP.headers('Content-Type': 'application/json', 'Accept': 'application/octet-stream', 'x-api-key': API_KEY).post(
    BASE_URL + url, json: { "assetIds": [asset_id] }
  )

  File.open("output/#{asset_id}.zip", 'w') { |file| file.write(resp.body) }
end

data = get_assets('56f834dc-e8fc-4a13-ba10-1e60256dc011')

# 1965795418
puts data['totalSize'] / 1024 / 1024

data['archives'].each do |archive|
  archive['assetIds'].each do |asset|
    download_asset(asset)
  end
end
