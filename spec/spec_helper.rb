require 'bundler'
Bundler.require

RSpec.configure do |c|
  c.before(:suite) do
    CreateSchema.suppress_messages{ CreateSchema.migrate(:up) }
  end

  c.after(:suite) do
    # FileUtils.rm_rf(File.expand_path('../test.db'), __FILE__)
  end
end

Dir[File.dirname(__FILE__) + '/support/*.rb'].each { |f| load f }
