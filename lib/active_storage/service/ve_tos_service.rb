# frozen_string_literal: true

require "active_storage/service"
require "tos"

module ActiveStorage
  class Service::VeTosService < Service
    attr_reader :bucket_name, :prefix, :public, :host, :upload_host

    def initialize(access_key_id:, secret_access_key:, region:, bucket:,
                   endpoint: nil, security_token: nil, public: false,
                   host: nil, upload_host: nil, prefix: nil, **)
      @client = TOS::Client.new(
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        region: region,
        endpoint: endpoint,
        security_token: security_token,
      )
      @bucket_name = bucket
      @prefix = prefix
      @public = public
      @host = host
      @upload_host = upload_host
    end

    def upload(key, io, checksum: nil, content_type: nil, disposition: nil, filename: nil, custom_metadata: {}, **)
      instrument :upload, key: key, checksum: checksum do
        body = io.respond_to?(:read) ? io.read : io.to_s
        bucket.put_object(
          path_for(key),
          body,
          content_type: content_type,
          content_md5: checksum,
          metadata: custom_metadata,
        )
      end
    end

    def download(key, &block)
      if block_given?
        instrument :streaming_download, key: key do
          bucket.get_object(path_for(key), &block)
        end
      else
        instrument :download, key: key do
          bucket.get_object(path_for(key)).body
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        bucket.get_object(path_for(key), range: range).body
      end
    end

    def delete(key)
      instrument :delete, key: key do
        bucket.delete_object(path_for(key))
      end
    rescue TOS::ServerError => e
      raise unless e.status == 404
    end

    def delete_prefixed(prefix_value)
      instrument :delete_prefixed, prefix: prefix_value do
        loop do
          page = bucket.list_objects(prefix: path_for(prefix_value), max_keys: 1000)
          break if page[:keys].empty?

          bucket.delete_multiple_objects(page[:keys])
          break unless page[:is_truncated]
        end
      end
    end

    def exist?(key)
      instrument :exist, key: key do |payload|
        answer = head?(path_for(key))
        payload[:exist] = answer
        answer
      end
    end

    def url(key, expires_in:, filename:, content_type:, disposition:, **)
      instrument :url, key: key do |payload|
        generated_url = if @public && @host
            public_url(key)
          else
            private_url(key, expires_in: expires_in, filename: filename,
                             content_type: content_type, disposition: disposition)
          end
        payload[:url] = generated_url
        generated_url
      end
    end

    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
      instrument :url, key: key do |payload|
        url = @client.presign(
          method: "PUT",
          bucket: @bucket_name,
          key: path_for(key),
          expires_in: expires_in.to_i,
        )
        url = url.sub(/^https:\/\/[^\/]+/, "https://#{@upload_host}") if @upload_host
        payload[:url] = url
        url
      end
    end

    def headers_for_direct_upload(_key, content_type:, checksum:, content_length:, custom_metadata: {}, **)
      headers = {
        "Content-Type" => content_type,
        "Content-Length" => content_length.to_s,
      }
      headers["Content-MD5"] = checksum if checksum
      custom_metadata.each { |k, v| headers["x-tos-meta-#{k}"] = v.to_s }
      headers
    end

    # Server-side compose isn't supported by this minimal SDK; download all
    # source keys and re-upload as a single object. Fine for small previews
    # (variants, thumbnails) but not for very large composites.
    def compose(source_keys, destination_key, filename: nil, content_type: nil, disposition: nil, custom_metadata: {})
      buffer = +""
      source_keys.each do |key|
        buffer << bucket.get_object(path_for(key)).body
      end

      bucket.put_object(
        path_for(destination_key),
        buffer,
        content_type: content_type,
        metadata: custom_metadata,
      )
    end

    private

    def bucket
      @bucket ||= @client.bucket(@bucket_name)
    end

    def head?(key)
      bucket.head_object(key)
      true
    rescue TOS::ServerError => e
      return false if e.status == 404

      raise
    end

    def path_for(key)
      [@prefix, key].compact.reject(&:empty?).join("/").gsub(%r{^/+}, "").squeeze("/")
    end

    def public_url(key)
      "https://#{@host}/#{@client.escape_key(path_for(key))}"
    end

    def private_url(key, expires_in:, filename: nil, content_type: nil, disposition: nil)
      query = {}
      if filename
        wrapped = ActiveStorage::Filename.wrap(filename)
        query["response-content-disposition"] = content_disposition_with(type: disposition, filename: wrapped)
      end
      query["response-content-type"] = content_type if content_type

      url = @client.presign(
        method: "GET",
        bucket: @bucket_name,
        key: path_for(key),
        query: query,
        expires_in: expires_in.to_i,
      )

      if @host
        url = url.sub(/^https:\/\/[^\/]+/, "https://#{@host}")
      end
      url
    end
  end
end
