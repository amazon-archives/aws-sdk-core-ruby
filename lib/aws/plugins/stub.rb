module Aws

  class << self

    # Enable stubbing
    def stub!
      # Add stub operations to each API implementation
      Aws.service_classes.values.each do |service_class|
        service_class.versioned_clients.each do |client|
          client.send(:include, Plugins::StubbedApi)
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

        # Create a Response, adding stubbed data
        # if appropriate
        # @param [RequestContext] context 
        def call(context)
          response = Seahorse::Client::Response.new(context: context)
          operation = context.operation_name.to_sym
          client = context.client
          if client.stub?(operation)
            client.next_stub(operation).process_response(response, client)
          end
          response
        end

      end

      # Replace the default send handler with this one
      handler(Handler, step: :send)

    end

    # Allows you to add stub metadata to the Aws service APIs
    module StubbedApi

      # Add stub data for the given operation
      # @param [Symbol] operation
      # @param [Object] data
      def add_stub(operation, data)
        validate_operation(operation)
        stubs_for(operation).push(DataStub.new(data))
      end

      # Raise an error for the given operation
      # @param [Symbol] operation
      # @param [String] error_code
      # @param [Integer] status_code
      def add_error(operation, error_code, status_code = 400)
        validate_operation(operation)
        stubs_for(operation).push(ErrorStub.new(error_code, status_code))
      end

      # @param [Symbol] operation
      # @return [Boolean]
      def stub?(operation)
        all_stubs.has_key?(operation)
      end

      # Get the next stub to use for the given operation.
      # If there is more than one stub, then remove the first
      # stub and return it, otherwise just return the first stub
      # @param [Symbol] operation
      # @return stub
      def next_stub(operation)
        if stub?(operation)
          stubs = stubs_for(operation)
          if stubs.length > 1
            stubs.shift
          else
            stubs.first
          end
        else
          nil
        end
      end

      # Reset stubs
      def reset_stubs!
        @all_stubs = nil
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
      # @return [Array]
      def stubs_for(operation)
        all_stubs[operation] ||= []
      end

      # @return [Hash]
      def all_stubs
        @all_stubs ||= {}
      end

      # Validate that the operation exists on this API
      # @param [Symbol] operation
      def validate_operation(operation)
        #raises error if invalid, defined in Seahorse::Client::Base
        operation(operation.to_s)
      end

    end

    # Assigns a simple Hash to the response
    class DataStub

      attr_reader :data

      # @param [Hash] data
      def initialize(data)
        @data = data
      end

      # @param [Seahorse::Client::Response] response
      # @param [StubbedApi] api
      def process_response(response, api)
        response.data = data
      end
    end

    # Puts the required error data into the response
    class ErrorStub

      attr_reader :error_code
      attr_reader :status_code

      # @param [String] error_code
      # @param [Integer] status_code
      def initialize(error_code, status_code=400)
        @error_code = error_code
        @status_code = status_code
      end

      # @param [Seahorse::Client::Response] response
      # @param [StubbedApi] api
      def process_response(response, api)
        response.http_response.status_code = status_code
        response.http_response.body = error_body(api)
      end

      # Format the error body for the appropriate protocol
      # (JSON or XML)
      # @param [StubbedApi] api
      def error_body(api)
        if api.json_protocol?
          # Aws::Json::ErrorParser expects a # at the start of the error code
          {code: "##{error_code}"}.to_json
        else
          "<Code>#{error_code}</Code>"
        end
      end
    end

  end

end
