require 'dropbox_sdk'

class DropboxDownloader
  include Sidekiq::Worker

  def perform(dropbox_uid, options={})
    @dropbox_uid = dropbox_uid
    @request_id = options['request_id']

    fetch_user_id
    fetch_token
    setup_clients

    @work_dir = Dir.mktmpdir
    log(work_dir: @work_dir)

    begin
      create_build_dir

      fetch_cursor_and_cache
      if @cursor
        extract_cache
      end

      fetch_delta

      @delta_entries.each do |entry|
        case entry.operation
        when :fetch
          fetch_file(entry.path)
        when :delete
          delete_file(entry.from_path)
        end
      end

      archive_cache
      upload_cache(@delta.cursor)
      schedule_build
    ensure
      FileUtils.remove_entry(@work_dir)
    end
  end

  def fetch_user_id
    @user_id = $redis.hget(dropbox_key, 'user_id')
  end

  def fetch_token
    encrypted_token = $redis.hget(dropbox_key, 'token')
    @token = decrypt(encrypted_token)
  end

  def setup_clients
    @dropbox = DropboxClient.new(@token)
    @s3      = AWS::S3.new
    @bucket  = @s3.buckets[Config.s3_bucket_name]
  end

  def create_build_dir
    FileUtils.mkdir(build_dir)
  end

  def fetch_cursor_and_cache
    log(fetch_cache: true) do
      obj = @bucket.objects[cache_name]
      return unless obj.exists?

      @cursor = obj.metadata['dropbox_cursor']

      log(fetch_cache: true, cache_hit: true, cache_name: cache_name) do
        File.open("#{@work_dir}/#{cache_name}", 'wb') do |file|
          obj.read do |chunk|
            file.write(chunk)
          end
        end
      end
    end
  end

  def extract_cache
    log(extract_cache: true) do
      path = Pathname.new("#{@work_dir}/#{cache_name}")
      return unless path.exist?
      `cd #{@work_dir} && tar xfz #{cache_name} -C #{build_dir}`
    end
  end

  def fetch_delta
    log(fetch_delta: true) do
      @delta = OpenStruct.new(@dropbox.delta(@cursor))
      @delta_entries = @delta.entries.map do |from_path, metadata|
        if metadata.nil?
          OpenStruct.new(from_path: from_path, operation: :delete)
        else
          OpenStruct.new(metadata.merge(from_path: from_path, operation: :fetch))
        end
      end
    end
  end

  def fetch_file(path)
    log(fetch_file: true, path: path) do
      contents = @dropbox.get_file(path)
      # TODO Construct paths correctly
      File.open("#{build_dir}/#{File.basename(path)}", 'wb') do |file|
        file.write(contents)
      end
    end
  end

  def delete_file(path)
    log(delete_file: true, path: path) do
      # TODO Deal with paths correctly
      # TODO Deal with dropbox's case insensitivity, see http://lostechies.com/derickbailey/2011/04/14/case-insensitive-dir-glob-in-ruby-really-it-has-to-be-that-cryptic/
      file_path = "#{build_dir}/#{File.basename(path)}"
      File.delete(file_path) if File.exist?(file_path)
    end
  end

  def archive_cache
    log(archive_cache: true, cache_name: cache_name) do
      `cd #{build_dir} && tar cfz ../#{cache_name} .`
    end
  end

  def upload_cache(cursor)
    log(upload_cache: true, cache_name: cache_name) do
      obj = @bucket.objects[cache_name]
      path = Pathname.new("#{@work_dir}/#{cache_name}")
      metadata = { dropbox_cursor: cursor }
      obj.write(path, content_type: 'application/x-gzip; charset=binary',
        metadata: metadata)
    end
  end

  def source_url
    log(source_url: true) do
      @bucket.objects[cache_name].url_for(:read)
    end
  end

  def schedule_build
    HerokuBuilder.perform_async(@user_id, source_url, @cursor, request_id: @request_id)
  end

  private

  def log(data={}, &blk)
    Pliny.log({ dropbox_downloader: true, user: @dropbox_uid, request_id: @request_id }.merge(data), &blk)
  end

  def build_dir
    "#{@work_dir}/build"
  end

  def dropbox_key
    "dropbox_#{@dropbox_uid}"
  end

  def cache_name
    "#{@dropbox_uid}.tar.gz"
  end

  def decrypt(message)
    verifier = Fernet.verifier(Config.fernet_secret, message)
    verifier.message
  end
end
