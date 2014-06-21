require 'dropbox_sdk'

class DropboxDownloader
  include Sidekiq::Worker

  def perform(user_id, options={})
    @user_id = user_id

    fetch_token
    setup_clients
    fetch_cursor

    @work_dir = Dir.mktmpdir
    Pliny.log(dropbox_user: @user_id, work_dir: @work_dir)

    begin
      create_build_dir

      if @cursor
        fetch_cache
        extract_cache
      end
      fetch_delta

      @delta_entries.each do |entry|
        fetch_file(entry.path)
      end

      archive_cache
      upload_cache
      store_cursor(@delta.cursor)
    ensure
      FileUtils.remove_entry(@work_dir)
    end
  end

  def fetch_token
    encrypted_token = $redis.hget("dropbox_#{@user_id}", 'token')
    @token = decrypt(encrypted_token)
  end

  def setup_clients
    @dropbox = DropboxClient.new(@token)
    @s3      = AWS::S3.new
    @bucket  = @s3.buckets[Config.s3_bucket_name]
  end

  def fetch_cursor
    @cursor = $redis.hget("dropbox_#{@user_id}", 'delta_cursor')
  end

  def create_build_dir
    FileUtils.mkdir(build_dir)
  end

  def fetch_cache
    Pliny.log(fetch_cache: true, dropbox_user: @user_id) do
      obj = @bucket.objects[cache_name]
      return unless obj.exists?

      Pliny.log(fetch_cache: true, cache_hit: true, cache_name: cache_name) do
        File.open("#{@work_dir}/#{cache_name}", 'wb') do |file|
          obj.read do |chunk|
            file.write(chunk)
          end
        end
      end
    end
  end

  def extract_cache
    Pliny.log(extract_cache: true, dropbox_user: @user_id) do
      path = Pathname.new("#{@work_dir}/#{cache_name}")
      return unless path.exist?
      `cd #{@work_dir} && tar xfz #{cache_name} -C #{build_dir}`
    end
  end

  def fetch_delta
    Pliny.log(fetch_delta: true, dropbox_user: @user_id) do
      @delta = OpenStruct.new(@dropbox.delta(@cursor))
      @delta_entries = @delta.entries.map do |from_path, metadata|
        OpenStruct.new(metadata.merge(from_path: from_path))
      end
    end
  end

  def fetch_file(path)
    Pliny.log(fetch_file: true, dropbox_user: @user_id, path: path) do
      contents = @dropbox.get_file(path)
      # TODO Construct paths correctly
      File.open("#{build_dir}/#{File.basename(path)}", 'wb') do |file|
        file.write(contents)
      end
    end
  end

  def archive_cache
    Pliny.log(archive_cache: true, cache_name: cache_name) do
      `cd #{build_dir} && tar cfz ../#{cache_name} .`
    end
  end

  def upload_cache
    Pliny.log(upload_cache: true, cache_name: cache_name) do
      obj = @bucket.objects[cache_name]
      path = Pathname.new("#{@work_dir}/#{cache_name}")
      obj.write(path, content_type: 'application/x-gzip; charset=binary')
    end
  end

  def store_cursor(cursor)
    $redis.hset("dropbox_#{@user_id}", 'delta_cursor', cursor)
  end

  private

  def build_dir
    "#{@work_dir}/build"
  end

  def cache_name
    "#{@user_id}.tar.gz"
  end

  def decrypt(message)
    verifier = Fernet.verifier(Config.fernet_secret, message)
    verifier.message
  end
end
