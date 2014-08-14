module Seahorse
  module Client
    module Plugins

      # @seahorse.client.option [String] :endpoint
      #    The HTTP or HTTPS endpoint to send requests to.
      #    For example:
      #
      #        'example.com'
      #        'http://example.com'
      #        'https://example.com'
      #        'http://example.com:123'
      #
      #    This must include the host.  It may also include the scheme and
      #    port.  When the scheme is not set it defaults to `https`.
      #
      class Endpoint < Plugin

        option(:endpoint)

        def after_initialize(client)
          endpoint = URI.parse(client.config.endpoint.to_s)
          if URI::HTTPS === endpoint or URI::HTTP === endpoint
            client.config.endpoint = endpoint
          else
            msg = 'expected :endpoint to be a HTTP or HTTPS endpoint'
            raise ArgumentError, msg
          end
        end

        class Handler < Client::Handler

          def call(context)
            context.http_request.endpoint = build_endpoint(context)
            @handler.call(context)
          end

          private

          def build_endpoint(context)
            uri = URI.parse(context.config.endpoint.to_s)
            apply_path_params(uri, context)
            apply_querystring_params(uri, context)
            uri
          end

          def apply_path_params(uri, context)
            path = uri.path.sub(/\/$/, '')
            path += context.operation.http_request_uri.split('?')[0]
            input = context.operation.input

            # Grab all placeholders
            placeholders = path.scan(/{\w+\+?}/)

            # Verify uniqueness - unsure if necessary
            if placeholders.uniq.length != placeholders.length
              msg = "non-unique uri params defined for endpoint"
              raise ArgumentError, msg
            end

            # Replace
            placeholders.each_with_index do |name, idx|
              sanitized = name.match(/(?<name>\w+)/)[:name]
              sanitized, shape = input.member_by_location_name(sanitized)
              param = context.params[sanitized]
              unless param
                if idx == placeholders.count - 1
                  param = ""
                else
                  msg = "non-trailing uri params must be defined!"
                  raise ArgumentError, msg
                end
              end

              param = (case name
                when /\w\+/
                  param.split('/').map{ |value| escape(value) }.join('/')
                else
                  escape(param)
                end
              )

              path.gsub!(name, param)
            end

            path.sub!(/\/$/, '')
            uri.path = path
          end

          def apply_querystring_params(uri, context)
            parts = []
            parts << context.operation.http_request_uri.split('?')[1]
            parts.compact!
            if input = context.operation.input
              params = context.params
              input.members.each do |member_name, member|
                if member.location == 'querystring' && !params[member_name].nil?
                  param_name = member.location_name
                  param_value = params[member_name]
                  parts << "#{param_name}=#{escape(param_value.to_s)}"
                end
              end
            end
            uri.query = parts.empty? ? nil : parts.join('&')
          end

          def escape(string)
            CGI::escape(string.encode('UTF-8')).gsub('+', '%20').gsub('%7E', '~')
          end

        end

        handle(Handler, priority: 90)

      end
    end
  end
end
