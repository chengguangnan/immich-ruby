# frozen_string_literal: true

require 'http'
require 'debug'

require 'yaml'

class Immich
  def initialize
    config = YAML.load_file("#{Dir.home}/.config/immich/auth.yml")
    @key = config['apiKey']
    @host = config['instanceUrl']
  end

  def download_info(album_id)
    url = "#{@host}/api/download/info"
    http_post.post(url, json: { "albumId": album_id }).parse
  end

  def download_archive(asset_id, dir)
    # /api/download/archive has the Live Photo audio file

    puts 'download_asset_zip'
    url = "#{@host}/api/download/archive"

    resp = HTTP.headers(accept: 'application/octet-stream', 'x-api-key': @key).post(
      url, json: { "assetIds": [asset_id] }
    )
    out = File.join(dir, "#{asset_id}.zip")
    File.open(out, 'w') { |file| file.write(resp.body) }
  end

  # def download_asset(asset_id, dir)
  #   url = "#{@host}/api/assets/#{asset_id}/original"
  #
  #   resp = HTTP.headers(accept: 'application/octet-stream', 'x-api-key': @key).get(
  #     url
  #   )
  #   out = File.join(dir, "#{asset_id}.zip")
  #   File.open(out, 'w') { |file| file.write(resp.body) }
  # end

  def get_album_info(album_id)
    http_get "#{@host}/api/albums/#{album_id}"
  end

  def albums
    http_get "#{@host}/api/albums"
  end

  def http_get(url)
    HTTP.headers(accept: 'application/json', 'x-api-key': @key).get(url).parse
  end

  def http_post
    HTTP.headers(:accept => 'application/json', 'x-api-key' => @key)
  end
end

require 'optimist'

opts = Optimist.options do
  opt :album, 'Album Name', type: :string
end

Optimist.die :album, '-album required' unless opts[:album_given]

puts opts

output_dir = 'downloads'

immich = Immich.new

require 'fileutils'

immich.albums.each do |album|
  next unless album['albumName'] == opts[:album]

  download_info = immich.download_info(album['id'])

  album_info = immich.get_album_info(album['id'])

  File.open(File.join(output_dir, "#{album['albumName']}.album-info.yaml"), 'w') do |out|
    YAML.dump(album_info, out)
  end

  File.open(File.join(output_dir, "#{album['albumName']}.album-archive.yaml"), 'w') do |out|
    YAML.dump(download_info, out)
  end

  #  debugger

  dir = "#{output_dir}/#{album['albumName']}"

  FileUtils.mkdir_p(dir)

  if download_info['statusCode'].nil?

    puts format('%d MB', (download_info['totalSize'] / 1024 / 1024))

    i = 0
    download_info['archives'].each do |archive|
      archive['assetIds'].each do |asset|
        i += 1
        puts format('%d / %d', i, album_info['assetCount'])
        immich.download_archive(asset, dir)
      end
    end

  else
    # {"statusCode"=>500, "message"=>"Internal server error"}
    puts download_info
  end
end
