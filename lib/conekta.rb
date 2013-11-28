# Conekta Ruby bindings
# API spec at https://conekta.io/docs/api
require 'cgi'
require 'set'
require 'openssl'
require 'rest_client'
require 'multi_json'
require 'base64'

# Version
require 'conekta/version'

# API operations
require 'conekta/api_operations/create'
require 'conekta/api_operations/update'
require 'conekta/api_operations/delete'
require 'conekta/api_operations/list'

# Resources
require 'conekta/util'
require 'conekta/json'
require 'conekta/conekta_object'
require 'conekta/api_resource'
require 'conekta/singleton_api_resource'
require 'conekta/account'
require 'conekta/list_object'
require 'conekta/charge'
require 'conekta/customer'
require 'conekta/token'
require 'conekta/event'
require 'conekta/log'

# Errors
require 'conekta/errors/conekta_error'
require 'conekta/errors/api_error'
require 'conekta/errors/api_connection_error'
require 'conekta/errors/card_error'
require 'conekta/errors/resource_not_found_error'
require 'conekta/errors/malformed_request_error'
require 'conekta/errors/parameter_validation_error'
require 'conekta/errors/authentication_error'

module Conekta
  @api_base = 'https://api.conekta.io'

  @ssl_bundle_path  = File.dirname(__FILE__) + '/data/ca-certificates.crt'
  @verify_ssl_certs = true

  class << self
    attr_accessor :api_key, :api_base, :verify_ssl_certs, :api_version
  end

  def self.api_url(url='')
    url = @api_base + url
    if not url.match(/\.json/)
      url = url + '.json'
    end
    url
  end

  def self.request(method, url, api_key, params={}, headers={})
    unless api_key ||= @api_key
      raise AuthenticationError.new('No API key provided. ' +
        'Set your API key using "Conekta.api_key = <API-KEY>". ' +
        'You can generate API keys from the Conekta web interface. ' +
        'See https://conekta.io/api for details, or email support@conekta.io ' +
        'if you have any questions.')
    end

    if api_key =~ /\s/
      raise AuthenticationError.new('Your API key is invalid, as it contains ' +
        'whitespace. (HINT: You can double-check your API key from the ' +
        'Conekta web interface. See https://conekta.io/api for details, or ' +
        'email support@conekta.io if you have any questions.)')
    end

    request_opts = { :verify_ssl => false }

    if ssl_preflight_passed?
      request_opts.update(:verify_ssl => OpenSSL::SSL::VERIFY_PEER,
                          :ssl_ca_file => @ssl_bundle_path)
    end

    params = Util.objects_to_ids(params)
    url = api_url(url)

    case method.to_s.downcase.to_sym
    when :get, :head, :delete
      # Make params into GET parameters
      url += "#{URI.parse(url).query ? '&' : '?'}#{uri_encode(params)}" if params && params.any?
      payload = nil
    else
      payload = params.to_json#uri_encode(params)
      headers[:content_type] = 'application/json'
    end

    request_opts.update(:headers => request_headers(api_key).update(headers),
                        :method => method, :open_timeout => 30,
                        :payload => payload, :url => url, :timeout => 80)

    begin
      response = execute_request(request_opts)
    rescue SocketError => e
      handle_restclient_error(e)
    rescue NoMethodError => e
      # Work around RestClient bug
      if e.message =~ /\WRequestFailed\W/
        e = APIConnectionError.new('Unexpected HTTP response code')
        handle_restclient_error(e)
      else
        raise
      end
    rescue RestClient::ExceptionWithResponse => e
      if rcode = e.http_code and rbody = e.http_body
        handle_api_error(rcode, rbody)
      else
        handle_restclient_error(e)
      end
    rescue RestClient::Exception, Errno::ECONNREFUSED => e
      handle_restclient_error(e)
    end

    [parse(response), api_key]
  end

  private

  def self.ssl_preflight_passed?
    if !verify_ssl_certs && !@no_verify
      $stderr.puts "WARNING: Running without SSL cert verification. " +
        "Execute 'Conekta.verify_ssl_certs = true' to enable verification."

      @no_verify = true

    elsif !Util.file_readable(@ssl_bundle_path) && !@no_bundle
      $stderr.puts "WARNING: Running without SSL cert verification " +
        "because #{@ssl_bundle_path} isn't readable"

      @no_bundle = true
    end

    !(@no_verify || @no_bundle)
  end

  def self.user_agent
    @uname ||= get_uname
    lang_version = "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})"

    {
      :bindings_version => Conekta::VERSION,
      :lang => 'ruby',
      :lang_version => lang_version,
      :platform => RUBY_PLATFORM,
      :publisher => 'conekta',
      :uname => @uname
    }

  end

  def self.get_uname
    `uname -a 2>/dev/null`.strip if RUBY_PLATFORM =~ /linux|darwin/i
  rescue Errno::ENOMEM => ex # couldn't create subprocess
    "uname lookup failed"
  end

  def self.uri_encode(params)
    Util.flatten_params(params).
      map { |k,v| "#{k}=#{Util.url_encode(v)}" }.join('&')
  end

  def self.request_headers(api_key)
    headers = {
      :user_agent => "Conekta RubyBindings/#{Conekta::VERSION}",
      :authorization => "Basic #{Base64.encode64(api_key+':')}"
    }

    if api_version
      headers.update(:accept=>"application/vnd.conekta-v#{api_version}+json")
    else
      headers.update(:accept=>"application/vnd.conekta-v0.3.0+json")
    end

    begin
      headers.update(:conekta_client_user_agent => Conekta::JSON.dump(user_agent))
    rescue => e
      headers.update(:conekta_client_raw_user_agent => user_agent.inspect,
                     :error => "#{e} (#{e.class})")
    end
  end

  def self.execute_request(opts)
    RestClient::Request.execute(opts)
  end

  def self.parse(response)
    begin
      # Would use :symbolize_names => true, but apparently there is
      # some library out there that makes symbolize_names not work.
      response = Conekta::JSON.load(response.body)
    rescue MultiJson::DecodeError
      raise general_api_error(response.code, response.body)
    end

    Util.symbolize_names(response)
  end

  def self.general_api_error(rcode, rbody)
    APIError.new("Invalid response object from API: #{rbody.inspect} " +
                 "(HTTP response code was #{rcode})", rcode, rbody)
  end

  def self.handle_api_error(rcode, rbody)
    begin
      error_obj = Conekta::JSON.load(rbody)
      error_obj = Util.symbolize_names(error_obj)
      error = error_obj or raise ConektaError.new # escape from parsing

    rescue MultiJson::DecodeError, ConektaError
      raise general_api_error(rcode, rbody)
    end

    case rcode
    when 400
      raise malformed_request_error error, rcode, rbody, error_obj
    when 401
      raise authentication_error error, rcode, rbody, error_obj
    when 402
      raise card_error error, rcode, rbody, error_obj
    when 404
      raise resource_not_found_error error, rcode, rbody, error_obj
    when 422
      raise parameter_validation_error error, rcode, rbody, error_obj
    else
      raise api_error error, rcode, rbody, error_obj
    end

  end

  def self.resource_not_found_error(error, rcode, rbody, error_obj)
    ResourceNotFoundError.new(error[:message], error[:param], rcode,
                            rbody, error_obj)
  end

  def self.malformed_request_error(error, rcode, rbody, error_obj)
    MalformedRequestError.new(error[:message], error[:param], rcode,
                            rbody, error_obj)
  end

  def self.parameter_validation_error(error, rcode, rbody, error_obj)
    ParameterValidationError.new(error[:message], error[:param], rcode,
                            rbody, error_obj)
  end

  def self.authentication_error(error, rcode, rbody, error_obj)
    AuthenticationError.new(error[:message], rcode, rbody, error_obj)
  end

  def self.card_error(error, rcode, rbody, error_obj)
    CardError.new(error[:message], error[:param], error[:code],
                  rcode, rbody, error_obj)
  end

  def self.api_error(error, rcode, rbody, error_obj)
    APIError.new(error[:message], rcode, rbody, error_obj)
  end

  def self.handle_restclient_error(e)
    case e
    when RestClient::ServerBrokeConnection, RestClient::RequestTimeout
      message = "Could not connect to Conekta (#{@api_base}). " +
        "Please check your internet connection and try again. " +
        "If this problem persists, you should check Conekta's service status at " +
        "https://twitter.com/conektastatus, or let us know at support@conekta.io."

    when RestClient::SSLCertificateNotVerified
      message = "Could not verify Conekta's SSL certificate. " +
        "Please make sure that your network is not intercepting certificates. " +
        "(Try going to https://api.conekta.io/ in your browser.) " +
        "If this problem persists, let us know at support@conekta.io."

    when SocketError
      message = "Unexpected error communicating when trying to connect to Conekta. " +
        "You may be seeing this message because your DNS is not working. " +
        "To check, try running 'host conekta.io' from the command line."

    else
      message = "Unexpected error communicating with Conekta. " +
        "If this problem persists, let us know at support@conekta.io."

    end

    raise APIConnectionError.new(message + "\n\n(Network error: #{e.message})")
  end
end
