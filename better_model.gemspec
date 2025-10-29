require_relative "lib/better_model/version"

Gem::Specification.new do |spec|
  spec.name        = "better_model"
  spec.version     = BetterModel::VERSION
  spec.authors     = [ "alessiobussolari" ]
  spec.email       = [ "alessio@cosmic.tech" ]
  spec.homepage    = "https://github.com/alessiobussolari/better_model"
  spec.summary     = "Rails engine gem that extends ActiveRecord model functionality"
  spec.description = "BetterModel is a Rails engine gem (Rails 8.1+) that provides powerful extensions for ActiveRecord models including declarative status management and more."
  spec.license     = "MIT"

  # Require Ruby 3.0 or higher
  spec.required_ruby_version = ">= 3.0.0"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["source_code_uri"] = "https://github.com/alessiobussolari/better_model"
  spec.metadata["changelog_uri"] = "https://github.com/alessiobussolari/better_model/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.1.0", "< 9.0"
end
