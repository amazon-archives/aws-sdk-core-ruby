require 'set'

module Aws
  module Plugins

    # @seahorse_client_option [Integer] :retry_limit (3)
    #   The maximum number of times to retry failed requests.  Only
    #   ~ 500 level server errors and certain ~ 400 level client errors
    #   are retried.  Generally, these are throttling errors, data
    #   checksum errors, networking errors, timeout errors and auth
    #   errors from expired credentials.
    class RetryErrors < Seahorse::Client::Plugin

      option(:retry_limit, 3)

      option(:retry_backoff, lambda { |c| Kernel.sleep(2 ** c.retries * 0.3) })

      # @api private
      class ErrorInspector

        EXPIRED_CREDS = Set.new([
          'InvalidClientTokenId',        # query services
          'UnrecognizedClientException', # json services
          'InvalidAccessKeyId',          # s3
          'AuthFailure',                 # ec2
        ])

        THROTTLING_ERRORS = Set.new([
          'Throttling',                             # query services
          'ThrottlingException',                    # json services
          'RequestThrottled',                       # sqs
          'ProvisionedThroughputExceededException', # dynamodb
          'RequestLimitExceeded',                   # ec2
          'BandwidthLimitExceeded',                 # cloud search
        ])

        CHECKSUM_ERRORS = Set.new([
          'CRC32CheckFailed', # dynamodb
        ])

        NETWORKING_ERRORS = Set.new([
          'RequestTimeout', # s3
        ])

        def initialize(error, http_status_code)
          @error = error
          @name = error.class.name.split('::').last
          @http_status_code = http_status_code
        end

        def expired_credentials?
          !!(EXPIRED_CREDS.include?(@name) || @name.match(/expired/i))
        end

        def throttling_error?
          !!(THROTTLING_ERRORS.include?(@name) || @name.match(/throttl/i))
        end

        def checksum?
          CHECKSUM_ERRORS.include?(@name) || @error.is_a?(Errors::ChecksumError)
        end

        def networking?
          NETWORKING_ERRORS.include?(@name) || @http_status_code == 0
        end

        def server?
          (500..599).include?(@http_status_code)
        end

      end

      class Handler < Seahorse::Client::Handler

        def call(context)
          response = @handler.call(context)
          if response.error
            retry_if_possible(response)
          else
            response
          end
        end

        private

        def retry_if_possible(response)
          context = response.context
          error = error_for(response)
          if should_retry?(context, error)
            retry_request(context, error)
          else
            response
          end
        end

        def error_for(response)
          ErrorInspector.new(response.error, response.http_response.status_code)
        end

        def retry_request(context, error)
          delay_retry(context)
          context.retries += 1
          context.config.credentials.refresh! if error.expired_credentials?
          context.http_request.body.rewind
          context.http_response.body.truncate(0)
          call(context)
        end

        def delay_retry(context)
          context.config.retry_backoff.call(context)
        end

        def should_retry?(context, error)
          retryable?(context, error) and
          context.retries < retry_limit(context) and
          response_truncatable?(context)
        end

        def retryable?(context, error)
          (error.expired_credentials? and refreshable_credentials?(context)) or
          error.throttling_error? or
          error.checksum? or
          error.networking? or
          error.server?
        end

        def refreshable_credentials?(context)
          context.config.credentials.respond_to?(:refresh!)
        end

        def retry_limit(context)
          context.config.retry_limit
        end

        def response_truncatable?(context)
          context.http_response.body.respond_to?(:truncate)
        end

      end

      def add_handlers(handlers, config)
        if config.retry_limit > 0
          handlers.add(Handler, step: :sign, priority: 99)
        end
      end

    end
  end
end
