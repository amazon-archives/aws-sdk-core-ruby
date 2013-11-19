module Aws
  module Signers
    class V2 < Base

      # @param [Http::Request] http_request
      def sign(http_request)
        params = http_request.body.param_list
        params.set('AWSAccessKeyId', @credentials.access_key_id)
        params.set('SecurityToken', @credentials.session_token) if
          @credentials.session_token
        params.set('Timestamp', Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'))
        params.set('SignatureVersion', '2')
        params.set('SignatureMethod', 'HmacSHA256')
        params.delete('Signature')
        params.set('Signature', signature(http_request, params))
        http_request.body = params.to_io
      end

      private

      def signature(http_request, params)
        sha256_hmac(string_to_sign(http_request, params))
      end

      def string_to_sign(http_request, params)
        [
          http_request.http_method,
          host(http_request),
          http_request.endpoint.path,
          params.to_s,
        ].join("\n")
      end

      def host(http_request)
        endpoint = http_request.endpoint
        host = endpoint.host.downcase
        if
          (endpoint.http? && endpoint.port != 80) ||
          (endpoint.https? && endpoint.port != 443)
        then
          host += ":#{endpoint.port}"
        end
        host
      end

    end
  end
end
