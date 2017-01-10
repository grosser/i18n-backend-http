require 'bundler/setup'
require 'bundler/gem_tasks'
require 'bump/tasks'
require 'wwtd/tasks'

require 'rake/testtask'
Rake::TestTask.new(:default) do |test|
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
  test.warning = false
end
