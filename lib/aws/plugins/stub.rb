module Aws

  class << self

    # Enable stubbing
    def stub!
      # Add stub operations to each API implementation
      Aws.service_classes.values.each do |service_class|
        service_class.versioned_clients.each do |client|
          client.send(:include, Plugins::ApiStub)
        end
      end
      Aws.add_plugin(Plugins::Stub)
    end

    # Disable stubbing
    def unstub!
      Aws.remove_plugin(Plugins::Stub)
    end
  end

  module Plugins

    # Stubs out AWS service APIs
    # Enable with
    #
    #     Aws.stub!
    #
    class Stub < Seahorse::Client::Plugin

      class Handler < Seahorse::Client::Handler

        def call(context)
          stub_response(context)
        end

        # Create a stubbed Response, adding stubbed data
        # if appropriate
        # @param [RequestContext] context 
        def stub_response(context)
          response = Seahorse::Client::Response.new(context: context)
          operation = context.operation_name.to_sym
          client = context.client
          if client.error?(operation)
            error = client.error(operation)
            response.http_response.status_code = error[:status_code]
            response.http_response.body = error_body(error, client)
          elsif client.stub?(operation)
            response.data = client.stub(operation)
          end
          response
        end

        # Format the error body for the appropriate protocol
        # (JSON or XML)
        # @param [Hash] error
        # @param [ApiStub] api
        def error_body(error, api)
          if api.json_protocol?
            # Aws::Json::ErrorParser expects a # at the start of the error code
            {code: "##{error[:error_code]}"}.to_json
          else
            "<Code>#{error[:error_code]}</Code>"
          end
        end

      end

      # Replace the default send handler with this one
      handler(Handler, step: :send)

    end

    # Allows you to add stub metadata to the Aws service APIs
    module ApiStub

      # Add stub data for the given operation
      # @param [Symbol] operation
      # @param [Object] data
      def add_stub(operation, data)
        validate_operation(operation)
        stubs[operation] = data
      end

      # Raise an error for the given operation
      # @param [Symbol] operation
      # @param [String] error_code
      # @param [Integer] status_code
      def add_error(operation, error_code, status_code = 400)
        validate_operation(operation)
        errors[operation] = {error_code: error_code, status_code: status_code}
      end

      # @param [Symbol] operation
      def stub?(operation)
        stubs.has_key?(operation)
      end

      # @param [Symbol] operation
      def error?(operation)
        errors.has_key?(operation)
      end

      # @param [Symbol] operation
      def stub(operation)
        stubs[operation]
      end

      # @param [Symbol] operation
      def error(operation)
        errors[operation]
      end

      # Reset stubs and errors
      def reset_stubs!
        @stubs = nil
        @errors = nil
      end

      # Find out if this API uses JSON
      def json_protocol?
        self.class.plugins.each do |plugin|
          if plugin <= Aws::Plugins::JsonProtocol
            return true
          end
        end
        false
      end

      private
      def stubs
        @stubs ||= {}
      end

      def errors
       @errors ||= {}
      end

      # Validate that the operation exists on this API
      # @param [Symbol] operation
      def validate_operation(operation)
        #raises error if invalid, defined in Seahorse::Client::Base
        operation(operation.to_s)
      end

    end
  end

end
