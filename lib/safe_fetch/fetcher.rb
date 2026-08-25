class SafeFetch::Fetcher
  def initialize(options)
    @options = options
  end

  def fetch
    with_tempfile do |tempfile|
      response = stream_response(tempfile)
      raise SafeFetch::HttpError, "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      tempfile.rewind
      yield SafeFetch::Result.new(
        tempfile: tempfile,
        filename: options.filename,
        content_type: normalized_content_type(response['content-type'])
      )
    end
  end

  private

  attr_reader :options

  def with_tempfile
    tempfile = Tempfile.new('chatwoot-safe-fetch', binmode: true)
    yield tempfile
  ensure
    tempfile&.close!
  end

  def stream_response(tempfile)
    bytes_written = 0

    perform_request do |res|
      next unless res.is_a?(Net::HTTPSuccess)

      validate_content_type!(res['content-type'])
      bytes_written = write_response_body(res, tempfile, bytes_written)
    end
  end

  # ssrf_filter's default resolver returns A and AAAA records mixed and
  # connects to whichever it picks. On hosts without IPv6 egress (Railway,
  # most containers) an AAAA pick fails with "Network unreachable", which
  # broke every agent-bot webhook after the v4.16.2 SSRF fix went live
  # ("Failed to open TCP connection to 2600:9000:..."). Prefer IPv4 and only
  # fall back to IPv6 when the hostname has no A records.
  IPV4_PREFERRED_RESOLVER = proc do |hostname|
    ips = ::Resolv.getaddresses(hostname).map { |ip| ::IPAddr.new(ip) }
    v4 = ips.reject(&:ipv6?)
    v4.empty? ? ips : v4
  end

  def perform_request(&)
    return SafeFetch::PrivateNetworkRequest.new(options).perform(&) if SafeFetch.allow_private_network?

    SsrfFilter.public_send(options.method, options.url, resolver: IPV4_PREFERRED_RESOLVER, **options.request_options, &)
  end

  def validate_content_type!(content_type)
    return unless options.validate_content_type?
    return if allowed_content_type?(content_type)

    raise SafeFetch::UnsupportedContentTypeError, "content-type not allowed: #{content_type}"
  end

  def write_response_body(response, tempfile, bytes_written)
    response.read_body do |chunk|
      bytes_written += chunk.bytesize
      raise SafeFetch::FileTooLargeError, "exceeded #{options.effective_max_bytes} bytes" if bytes_written > options.effective_max_bytes

      tempfile.write(chunk)
    end

    bytes_written
  end

  def allowed_content_type?(value)
    mime = normalized_content_type(value)
    return false if mime.blank?

    options.allowed_content_type_prefixes.any? { |prefix| mime.start_with?(prefix) } ||
      options.allowed_content_types.include?(mime)
  end

  def normalized_content_type(value)
    value.to_s.split(';').first&.strip&.downcase
  end
end
