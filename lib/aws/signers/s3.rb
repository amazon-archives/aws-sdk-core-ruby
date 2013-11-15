require 'set'
require 'time'
require 'digest/sha1'
require 'openssl'
require 'uri'

module Aws
  module Signers
    class S3

      SIGNED_QUERYSTRING_PARAMS = Set.new(%w(

        acl delete cors lifecycle location logging notification partNumber
        policy requestPayment restore tagging torrent uploadId uploads
        versionId versioning versions website

        response-content-type response-content-language
        response-expires response-cache-control
        response-content-disposition response-content-encoding

      ))

      def self.sign(context)
        new(
          context.config.credentials,
          context.params
        ).sign(context.http_request)
      end

      # @param [Credentials] credentials
      def initialize(credentials, params)
        @credentials = credentials
        @params = Query::ParamList.new
        params.each_pair do |param_name, param_value|
          @params.set(param_name, param_value)
        end
      end

      attr_reader :credentials, :params

      def sign(request)
        if token = credentials.session_token
          request.headers["X-Amz-Security-Token"] = token
        end
        request.headers['Authorization'] = authorization(request)
      end

      # @param [RequestContext] context
      def self.sign(context)
        new(context.config.credentials, context.params).
          sign(context.http_request)
      end

      private

      def authorization(request)
        "AWS #{credentials.access_key_id}:#{signature(request)}"
      end

      def signature(request)
        secret = credentials.secret_access_key
        string_to_sign = string_to_sign(request)
        signature = digest(credentials.secret_access_key, string_to_sign)
        URI.escape(signature)
      end

      def digest(secret, string_to_sign)
        Base64.encode64(hmac(secret, string_to_sign)).strip
      end

      def hmac(key, value)
        OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha1'), key, value)
      end

      # From the S3 developer guide:
      #
      #     StringToSign =
      #       HTTP-Verb ` "\n" `
      #       content-md5 ` "\n" `
      #       content-type ` "\n" `
      #       date ` "\n" `
      #       CanonicalizedAmzHeaders + CanonicalizedResource;
      #
      def string_to_sign(request)
        [
          request.http_method,
          request.headers.values_at('Content-Md5', 'Content-Type').join("\n"),
          signing_string_date(request),
          canonicalized_headers(request),
          canonicalized_resource(request),
        ].flatten.compact.join("\n")
      end

      def signing_string_date(request)
        # if a date is provided via x-amz-date then we should omit the
        # Date header from the signing string (should appear as a blank line)
        if request.headers.detect{|k,v| k.to_s =~ /^x-amz-date$/i }
          ''
        else
          request.headers['Date'] = Time.now.httpdate
        end
      end

      # CanonicalizedAmzHeaders
      #
      # See the developer guide for more information on how this element
      # is generated.
      #
      def canonicalized_headers(request)
        x_amz = request.headers.select{|k, v| k =~ /^x-amz-/i }
        x_amz = x_amz.collect{|k, v| [k.downcase, v] }
        x_amz = x_amz.sort_by{|k, v| k }
        x_amz = x_amz.collect{|k, v| "#{k}:#{v.to_s.strip}" }.join("\n")
        x_amz == '' ? nil : x_amz
      end

      # From the S3 developer guide
      #
      #     CanonicalizedResource =
      #       [ "/" ` Bucket ] `
      #       <HTTP-Request-URI, protocol name up to the querystring> +
      #       [ sub-resource, if present. e.g. "?acl", "?location",
      #       "?logging", or "?torrent"];
      #
      # @api private
      def canonicalized_resource(request)

        parts = []

        # virtual hosted-style requests require the hostname to appear
        # in the canonicalized resource prefixed by a forward slash.
        if bucket = params[:bucket]
          ssl = request.endpoint.https?
          if Plugins::S3BucketDns.dns_compatible?(bucket.name, ssl)
            parts << "/#{bucket.value}"
          end
        end

        # append the path name (no querystring)
        parts << request.endpoint.path

        # lastly any sub resource querystring params need to be appened
        # in lexigraphical ordered joined by '&' and prefixed by '?'
        params = signed_querystring_params(request)

        unless params.empty?
          parts << '?'
          parts << params.sort.collect{|p| p.to_s }.join('&')
        end

        parts.join
      end

      def signed_querystring_params(request)
        request.endpoint.querystring.to_s.split('&').select do |p|
          SIGNED_QUERYSTRING_PARAMS.include?(p.split('=')[0])
        end.map { |p| URI.decode(p) }
      end

    end
  end
end
