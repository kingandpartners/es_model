require_relative 'lib/es_model/version'

Gem::Specification.new do |spec|
  spec.name          = "es_model"
  spec.version       = EsModel::VERSION
  spec.authors       = ["Justin Grubbs"]
  spec.email         = ["justin@kingandpartners.com"]

  spec.summary       = %q{Ruby connector to ElasticPress data.}
  spec.description   = %q{Ruby connector to ElasticPress data.}
  spec.homepage      = "https://github.com/kingandpartners/es_model"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kingandpartners/es_model"
  spec.metadata["changelog_uri"] = "https://github.com/kingandpartners/es_model/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency "elasticsearch", "~> 6.2"
  spec.add_dependency "activesupport"
  spec.add_dependency "faraday_middleware-aws-sigv4"
end
