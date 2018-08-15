require 'rake/clean'
require 'rake/testtask'

CLEAN << FileList['monitor.log.*']

Rake::TestTask.new do |test|
  test.libs << %w(test)
  test.pattern = 'test/**/*_test.rb'
end

task :default => :test
