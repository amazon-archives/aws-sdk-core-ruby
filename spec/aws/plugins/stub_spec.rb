require 'spec_helper'

module Aws
  module Plugins
    describe Stub do

      before(:all) do 
        Aws.stub!
        Aws.config[:credentials] = dummy_credentials
        Aws.config[:region] = 'dummy-region'
      end

      after(:all) do
        Aws.unstub!
      end

      let(:ec2) { Aws::EC2.new }

      it 'no-ops operations' do
        response = ec2.describe_instances
        expect(response.data).to be_nil
      end

      it 'fails for bogus operation' do
        expect{ ec2.add_stub(:foobar) }.to raise_error
      end

      it 'stubs data' do
        ec2.add_stub(:describe_instances, {foo: 'bar'})
        response = ec2.describe_instances
        expect(response.data).not_to be_nil
        expect(response.data[:foo]).to eq 'bar'
      end

      it 'stubs multiple responses' do
        ec2.add_stub(:describe_instances, {foo: 'bar'})
        ec2.add_error(:describe_instances, "Blocked")
        ec2.add_stub(:describe_instances, {foo: 'baz'})
        expect(ec2.describe_instances.data[:foo]).to eq 'bar'
        expect{ ec2.describe_instances }.to raise_error
        expect(ec2.describe_instances.data[:foo]).to eq 'baz'
        expect(ec2.describe_instances.data[:foo]).to eq 'baz'
      end

      it 'raises expected error' do
        ec2.add_error(:describe_instances, "Blocked")
        expect{ ec2.describe_instances }.to raise_error(Aws::EC2::Errors::Blocked)
      end

      it 'raises expected error for JSON protocol' do
        kinesis = Aws::Kinesis.new
        kinesis.add_error(:describe_stream, "ResourceNotFoundException")
        expect do 
          kinesis.describe_stream(stream_name: "foo") 
        end.to raise_error(Aws::Kinesis::Errors::ResourceNotFoundException)
      end

    end
  end
end
