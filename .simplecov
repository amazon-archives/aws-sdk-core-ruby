if ENV['COVERAGE']
  SimpleCov.start do
    add_filter 'spec'
    add_filter 'features'
  end
end
