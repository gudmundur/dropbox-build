module Workers
  class DropboxDownloader
    include Sidekiq::Worker

    def perform(dropbox_uid, options={})
      @dropbox_uid = dropbox_uid
      @request_id = options['request_id']

      begin
        fetch_user_id
        verify_app_attached
        setup_clients
      rescue Errors::AuthenticationMissing
        log(auth_missing: true)
        return
      rescue Errors::AppMissing
        log(app_missing: true)
        return
      end

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
          when :create_dir
            create_dir(entry.path, entry)
          when :fetch
            fetch(entry.path, entry)
          when :delete
            delete(entry.from_path)
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
      raise Errors::AuthenticationMissing unless @user_id
    end

    def verify_app_attached
      app_id = $redis.hget("heroku_#{@user_id}", 'app_id')
      raise Errors::AppMissing unless app_id
    end

    def setup_clients
      @dropbox = DropboxClient.connect_redis(@user_id)
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
          elsif metadata['is_dir']
            OpenStruct.new(metadata.merge(from_path: from_path, operation: :create_dir))
          else
            OpenStruct.new(metadata.merge(from_path: from_path, operation: :fetch))
          end
        end
      end
    end

    def create_dir(path, metadata={})
      log(create_dir: true, path: path) do
        dir = File.join(build_dir, path)
        FileUtils.mkdir(dir) unless Dir.exists?(dir)
      end
    end

    def fetch(path, metadata={})
      log(fetch_file: true, path: path) do
        full_path = File.join(build_dir, path)
        contents = @dropbox.get_file(path)
        File.open(full_path, 'wb') do |file|
          file.write(contents)
        end
      end
    end

    def delete(path)
      log(delete: true, path: path) do
        # TODO Deal with paths correctly
        # TODO Deal with dropbox's case insensitivity, see http://lostechies.com/derickbailey/2011/04/14/case-insensitive-dir-glob-in-ruby-really-it-has-to-be-that-cryptic/
        full_path = File.join(build_dir, path)
        return Dir.unlink(full_path) if File.directory?(full_path)
        return File.delete(full_path) if File.file?(full_path)
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
end
