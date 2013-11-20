module Aws
  module Plugins

    # @seahorse.client.option [String] :access_key_id Your AWS account
    #   access key ID.  Defaults to `ENV['AWS_ACCESS_KEY_ID']`.
    #
    # @seahorse.client.option [String] :secret_access_key Your AWS account
    #   secret access key.  Defaults to `ENV['AWS_SECRET_ACCESS_KEY']`.
    #
    # @seahorse.client.option [String] :session_token If your credentials
    #   are temporary session credentials, this should be the
    #   session token.  Defaults to `ENV['AWS_SESSION_TOKEN']`.
    #
    # @seahorse.client.option [Credentials] :credentials
    #   Your AWS account credentials.  Defaults to a new {Credentials} object
    #   populated by `:access_key_id`, `:secret_access_key` and
    #   `:session_token`.
    #
    class Credentials < Seahorse::Client::Plugin

      require 'configparser'

      option(:parser) do |config|
        config_file = "#{ENV['HOME']}/.aws/config"
        if File.exist?(config_file)
          ConfigParser.new(config_file)['default']
        else
          {}
        end
      end

      option(:access_key_id) do |config|
        ENV['AWS_ACCESS_KEY_ID'] ||
        ENV['AMAZON_ACCESS_KEY_ID'] ||
        config.parser['aws_access_key_id']
      end

      option(:secret_access_key) do |config|
        ENV['AWS_SECRET_ACCESS_KEY'] ||
        ENV['AMAZON_SECRET_ACCESS_KEY'] ||
        config.parser['aws_secret_access_key']
      end

      option(:session_token) do |config|
        ENV['AWS_SESSION_TOKEN'] ||
        ENV['AMAZON_SESSION_TOKEN'] ||
        config.parser['aws_security_token']
      end

      option(:credentials) do |config|
        Aws::Credentials.new(
          config.access_key_id,
          config.secret_access_key,
          config.session_token)
      end

      def after_initialize(client)
        if client.config.credentials.nil? or !client.config.credentials.set?
          raise Errors::MissingCredentialsError
        end
      end

    end
  end
end
