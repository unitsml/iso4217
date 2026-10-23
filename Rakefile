# frozen_string_literal: true

desc "Validate the generated database against ISO 4217 invariants"
task :validate do
  ruby "scripts/validate.rb"
end

desc "Regenerate data/ from raw/ and validate"
task :convert do
  sh "ruby scripts/convert.rb"
  Rake::Task[:validate].invoke
end

desc "Check data/ matches a fresh regeneration (determinism gate)"
task :check do
  require "digest"
  before = Dir["data/*.yaml"].sort.map { |f| [f, Digest::SHA256.file(f).hexdigest] }.to_h
  sh "ruby scripts/convert.rb"
  after = Dir["data/*.yaml"].sort.map { |f| [f, Digest::SHA256.file(f).hexdigest] }.to_h
  abort "data/ stale — run `rake convert` and commit" unless before == after
  Rake::Task[:validate].invoke
end

task default: :check
