version = File.read(File.expand_path('../../VERSION', __FILE__)).strip

Gem::Specification.new do |spec|

  spec.name          = 'aws-sdk-core'
  spec.version       = version
  spec.summary       = 'AWS SDK for Ruby - Core'
  spec.description   = 'Provides API clients for AWS.'
  spec.author        = 'Amazon Web Services'
  spec.homepage      = 'http://github.com/aws/aws-sdk-core-ruby'
  spec.license       = 'Apache 2.0'

  spec.require_paths = ['lib']

  spec.files = ['endpoints.json']
  spec.files += ['aws.rb.1']
  spec.files += Dir['lib/**/*.rb']
  spec.files += Dir['apis/*.json'].select { |p| !p.match(/\.docs\.json$/) }

  spec.bindir = 'bin'
  spec.executables << 'aws.rb'

  spec.add_dependency('multi_json', '~> 1.0')
  spec.add_dependency('multi_xml', '~> 0.5')
  spec.add_dependency('builder', '~> 3.0')
  spec.add_dependency('jamespath', '>= 0.5.1')

end
