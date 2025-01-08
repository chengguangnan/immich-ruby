# frozen_string_literal: true

require 'http'
require 'debug'
require 'fileutils'
require 'zip'
require 'yaml'
require 'time'
require 'optimist'

class Immich
  def initialize
    config = YAML.load_file("#{Dir.home}/.config/immich/auth.yml")
    @key = config['apiKey']
    @host = config['instanceUrl']
    @http = HTTP.persistent(@host)
  end

  def download_info(album_id)
    url = "#{@host}/api/download/info"
    http_post.post(url, json: { "albumId": album_id }).parse
  end

  def download_archive(asset_id, dir, album_info, flatten_dir)
    unzipped_dir = File.join(dir, '..', "unzipped/#{asset_id}")
    FileUtils.mkdir_p(unzipped_dir)

    out = File.join(dir, "#{asset_id}.zip")

    unless File.exist?(out)
      puts "Downloading #{asset_id}"
      url = "#{@host}/api/download/archive"

      resp = @http.headers(accept: 'application/octet-stream', 'x-api-key': @key).post(
        url, json: { "assetIds": [asset_id] }
      )

      File.open(out, 'w') { |file| file.write(resp.body) }
    end

    # Extract files using rubyzip
    Zip::File.open(out) do |zip_file|
      zip_file.each do |entry|
        entry.extract(File.join(unzipped_dir, entry.name)) { true } # Overwrite existing files
      end
    end

    puts format('children %d %s', Dir.children(unzipped_dir).size, asset_id)

    date_time = album_info['assets'].to_h { |x| [x['id'], x['exifInfo']['dateTimeOriginal']] }

    exif = album_info['assets'].to_h { |x| [x['id'], x] }

    Dir.children(unzipped_dir).each do |entry|
      src = File.join(unzipped_dir, entry)

      if date_time[asset_id]
        dest = File.join(flatten_dir, date_time[asset_id] + File.extname(entry).downcase)
        FileUtils.mv(src, dest)

        # Set the file's timestamp
        timestamp = Time.parse(date_time[asset_id])
        File.utime(timestamp, timestamp, dest)
      else
        puts exif[asset_id]
      end
    end
  end

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
    HTTP.headers(:accept => 'application/json', 'x-api-key': @key)
  end
end

class Export
  def initialize(dir)
    @dir = dir
    FileUtils.mkdir_p(zipped)
    FileUtils.mkdir_p(unzipped)
    FileUtils.mkdir_p(flatten)
  end

  attr_reader :dir

  def zipped
    File.join(@dir, 'zipped')
  end

  def unzipped
    File.join(@dir, 'unzipped')
  end

  def flatten
    File.join(@dir, 'flatten')
  end
end

opts = Optimist.options do
  opt :album, 'Album Name', type: :string
end

Optimist.die :album, '-album required' unless opts[:album_given]

immich = Immich.new

immich.albums.each do |album|
  next unless album['statusCode'].nil?
  next unless album['albumName'] == opts[:album]

  download_info = immich.download_info(album['id'])
  export = Export.new("downloads/#{album['albumName']}")
  album_info = immich.get_album_info(album['id'])

  File.open(File.join(export.dir, 'album-info.yaml'), 'w') do |out|
    YAML.dump(album_info, out)
  end

  File.open(File.join(export.dir, 'album-archive.yaml'), 'w') do |out|
    YAML.dump(download_info, out)
  end

  if download_info['statusCode'].nil?
    puts format('%d MB', (download_info['totalSize'] / 1024 / 1024))

    i = 0
    download_info['archives'].each do |archive|
      archive['assetIds'].each do |asset|
        i += 1
        puts format('%d / %d', i, album_info['assetCount'])
        immich.download_archive(asset, export.zipped, album_info, export.flatten)
      end
    end
  else
    puts download_info
  end
end
