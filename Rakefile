require 'bundler/setup'
require 'appraisal'
require 'bundler/gem_tasks'
require 'bump/tasks'

task :default do
  sh "bundle exec rake appraisal:install && bundle exec rake appraisal test"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end
