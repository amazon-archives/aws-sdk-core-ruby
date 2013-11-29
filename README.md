# AWS SDK Core [![Build Status](https://travis-ci.org/aws/aws-sdk-core-ruby.png?branch=master)](https://travis-ci.org/aws/aws-sdk-core-ruby) [![Code Climate](https://codeclimate.com/github/aws/aws-sdk-core-ruby.png)](https://codeclimate.com/github/aws/aws-sdk-core-ruby)

This library is in a developer preview period.

We are working on version 2 of the official AWS SDK for Ruby.  This library
is the first part of our v2 strategy.  AWS SDK Core is an updated set of
service clients.  Our goal is to make them more flexible and extensible
than the clients in version 1 of the Ruby SDK.

For version 1.0 of the Ruby SDK, see [aws/aws-sdk-ruby](http://github.com/aws/aws-sdk-ruby).

## Links of Interest

* [Documentation](http://docs.amazonwebservices.com/sdkforruby/api/frames.html)
* [Release Notes](http://aws.amazon.com/releasenotes/SDK/Ruby/Core)
* [Issues](http://github.com/aws/aws-sdk-core-ruby/issues)
* [Forums](https://forums.aws.amazon.com/forum.jspa?forumID=125)
* [License](http://aws.amazon.com/apache2.0/)

## Installation

You can install the AWS SDK Core from rubygems:

    gem install aws-sdk-core --pre

If you are using Bundler, we recommend that you express a major version
dependency (this library uses [semantic versioning](http://semver.org/)):

    gem 'aws-sdk-core', '~> 2.0'

Until the final release becomes available on Rubygems, leave off the version
dependency in your Gemfile so Bundler can find it.

**Note:** AWS SDK Core requires Ruby 1.9.3+.

## Configuration

At a minimum, you need to configure your AWS account access credentials and a
default region.  You can supply these globally or per service object.

```ruby
require 'aws-sdk-core'

# Aws.config is used for default configuration.
# You can construct service object with the same options.
Aws.config = { access_key_id: '...', secret_access_key: '...', region: 'us-west-2' }
```

Additionally, the SDK will attempt to load these options from `ENV`:

    export AWS_ACCESS_KEY_ID='...'
    export AWS_SECRET_ACCESS_KEY='...'
    export AWS_REGION='us-west-2'

## Basic Usage

To make a request, you need to construct a service client.

```ruby
s3 = Aws::S3.new
s3 = Aws.s3 # helper method returns a new client
```

Each client provides one operation per API operation. Refer to the
[API documentation](http://docs.amazonwebservices.com/sdkforruby/api/frames.html)
for a complete list of available methods.

```ruby
# get a list of buckets in Amazon S3
resp = s3.list_buckets
puts resp.buckets.map(&:name)
```

API methods each accept a hash of params and return a structured response.

```ruby
resp = s3.list_objects(bucket: 'aws-sdk-core', max_keys: 2)
resp.contents.each do |object|
  puts "#{object.key} => #{object.etag}"
end
```

## Paging Responses

Many AWS operations limit the number of results returned with each response.
A simple paging interface is provided that works with every AWS request.

```ruby
# yields once per response, even works with non-paged requests
s3.list_objects(bucket:'aws-sdk').each do |resp|
  puts resp.contents.map(&:key)
end
```

If you prefer to control paging yourself, all returned responses have the
same helper methods:

```ruby
# make a request that returns a truncated response
resp = s3.list_objects(bucket:'aws-sdk')

resp.last_page? #=> false
resp.next_page? #=> true
resp = resp.next_page # send a request for the next response page
resp = resp.next_page until resp.last_page?
```

The data in the response is accessible via the [data](http://docs.aws.amazon.com/sdkforruby/api/Seahorse/Client/Response.html#data-instance_method) method which returns a struct:
```ruby
# example: request a metric from CloudWatch using get_metric_statistics
metric = cw.get_metric_statistics(
  :namespace => "AWS/Billing",
  :metric_name => "EstimatedCharges",
  :dimensions => [
    {
      :name => "ServiceName",
      :value => "AmazonS3",
    },
    ...
  ],
  ...
)
puts metric.data
#<struct label="EstimatedCharges", datapoints=[#<struct timestamp=2013-11-28 17:10:00 UTC, sample_count=nil, average=nil, sum=nil, minimum=nil, maximum=1234.56, unit="None">]>
```

Refer to the 'Response Structure' tab in the documentation for each client.

## Data Iteration Examples

You can access the data in your response structs in a number of ways.
Here are a couple of examples to get you started.

S3 Bucket ACLs:
```ruby
# get a list of buckets
my_buckets = s3.list_buckets.buckets.map(&:name)

# iterate buckets and output the owner and permissions
my_buckets.each do |bucket|
  s3.get_bucket_acl(:bucket => bucket).grants.each do |grant|
    owner      = grant.grantee.display_name
    permission = grant.permission
    
    puts "Bucket '#{bucket}' grants user '#{owner.nil? ? "Everyone" : owner}' with '#{permission}'"
  end
end
```

S3 Bucket Logging:
```ruby
# get a list of buckets
my_buckets = s3.list_buckets.buckets.map(&:name)

# iterate buckets and check if they have logging enabled
my_buckets.each do |bucket|
  target_logging_bucket = s3.get_bucket_logging(:bucket => bucket).logging_enabled
  
  if target_logging_bucket.nil?
    puts "Bucket '#{bucket}' doesn't have bucket logging enabled."
  else
    puts "Bucket '#{bucket}' is logging to bucket '#{target_logging_bucket.target_bucket}'"+
         " in prefix '#{target_logging_bucket.target_prefix}'."
  end
end
```

Billing Estimated Charges:
```ruby
# get a billing metric
metric = cw.get_metric_statistics(
  :namespace => "AWS/Billing",
  :metric_name => "EstimatedCharges",
  :dimensions => [
    {
      :name => "ServiceName",
      :value => "AmazonS3",
    },
    {
      :name => 'Currency',
      :value => 'USD'
    }
  ],
  :start_time => Time.now - 24 * 60 * 60,
  :end_time => Time.now,
  :period => 24 * 60 * 60,
  :statistics => ["Minimum","Maximum"]
  )

metric.datapoints.each do |dp|
  puts "Over the past 24hrs our S3 cost has increased $#{(dp.maximum - dp.minimum).round(2)}"+
       " from $#{dp.minimum} to $#{dp.maximum}."
end
```


## Interactive Console

AWS SDK Core ships with a REPL that acts as an interactive console. You
can access the REPL by running `aws.rb` from the command line.

```ruby
$ aws.rb
Aws> ec2.describe_instances.reservations.first.instances.first
<struct
 instance_id="i-1234567",
 image_id="ami-7654321",
 state=<struct  code=16, name="running">,
 ...>
```

Call `#service_classes` to get a list of available service helpers and
the class they construct.

```ruby
Aws> service_classes
{:autoscaling=>Aws::AutoScaling,
 :cloudformation=>Aws::CloudFormation,
 :cloudfront=>Aws::CloudFront,
 :cloudsearch=>Aws::CloudSearch,
 ...
 :swf=>Aws::SWF}
```

## Versioning

This project uses [semantic versioning](http://semver.org/). When the project
leaves the developer preview state, we will continue by versioning from
`2.0`.  Until then, all versions will be suffixed by a release candidate
version.

## Supported Services

| Service Name                        | Service Class             | API Versions                   |
| ----------------------------------- | ------------------------- | ------------------------------ |
| Amazon CloudFront                   | Aws::CloudFront           | 2012-05-05 &mdash; 2013-08-26  |
| Amazon CloudSearch                  | Aws::CloudSearch          | 2011-02-01                     |
| Amazon CloudWatch                   | Aws::CloudWatch           | 2010-08-01                     |
| Amazon DynamoDB                     | Aws::DynamoDB             | 2011-12-05 &mdash; 2012-08-10  |
| Amazon Elastic Compute Cloud        | Aws::EC2                  | 2013-06-15 &mdash; 2013-10-01  |
| Amazon Elastic MapReduce            | Aws::EMR                  | 2009-03-31                     |
| Amazon Elastic Transcoder           | Aws::ElasticTranscoder    | 2012-09-25                     |
| Amazon ElastiCache                  | Aws::ElastiCache          | 2012-11-15 &mdash; 2013-06-15  |
| Amazon Glacier                      | Aws::Glacier              | 2012-06-01                     |
| Amazon Redshift                     | Aws::Redshift             | 2012-12-01                     |
| Amazon Relational Database Service  | Aws::RDS                  | 2013-01-10 &mdash; 2013-05-15  |
| Amazon Route 53                     | Aws::Route53              | 2012-12-12                     |
| Amazon Simple Email Service         | Aws::SES                  | 2010-12-01                     |
| Amazon Simple Notification Service  | Aws::SNS                  | 2010-03-31                     |
| Amazon Simple Queue Service         | Aws::SQS                  | 2012-11-05                     |
| Amazon Simple Storage Service       | Aws::S3                   | 2006-03-01                     |
| Amazon Simple Workflow Service      | Aws::SWF                  | 2012-01-25                     |
| Amazon SimpleDB                     | Aws::SDB                  | 2009-04-15                     |
| Auto Scaling                        | Aws::AutoScaling          | 2011-01-01                     |
| AWS CloudFormation                  | Aws::CloudFormation       | 2010-05-15                     |
| AWS Data Pipeline                   | Aws::DataPipeline         | 2012-10-29                     |
| AWS Direct Connect                  | Aws::DirectConnect        | 2012-10-25                     |
| AWS Elastic Beanstalk               | Aws::ElasticBeanstalk     | 2010-12-01                     |
| AWS Identity and Access Management  | Aws::IAM                  | 2010-05-08                     |
| AWS Import/Export                   | Aws::ImportExport         | 2010-06-01                     |
| AWS OpsWorks                        | Aws::OpsWorks             | 2013-02-18                     |
| AWS Security Token Service          | Aws::STS                  | 2011-06-15                     |
| AWS Storage Gateway                 | Aws::StorageGateway       | 2012-06-30 &mdash; 2013-06-30  |
| AWS Support                         | Aws::Support              | 2013-04-15                     |
| Elastic Load Balancing              | Aws::ElasticLoadBalancing | 2012-06-01                     |

## License

This library is distributed under the
[apache license, version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)

```no-highlight
copyright 2013. amazon web services, inc. all rights reserved.

licensed under the apache license, version 2.0 (the "license");
you may not use this file except in compliance with the license.
you may obtain a copy of the license at

    http://www.apache.org/licenses/license-2.0

unless required by applicable law or agreed to in writing, software
distributed under the license is distributed on an "as is" basis,
without warranties or conditions of any kind, either express or implied.
see the license for the specific language governing permissions and
limitations under the license.
```
