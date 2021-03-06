require_relative 'lib/rahel/version'

Gem::Specification.new do |spec|
  spec.name          = "rahel"
  spec.version       = Rahel::VERSION
  spec.authors       = ["Johannes Schäffer"]
  spec.email         = ["schaeffer.johannes@gmail.com"]

  spec.summary       = %q{Write a short summary, because RubyGems requires one.}
  spec.description   = %q{Write a longer description or delete this line.}
  spec.homepage      = "https://wissenschaftliche-sammlungen.de"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/j-schaeffer/rahel.git"
  spec.metadata["changelog_uri"] = "https://wissenschaftliche-sammlungen.de"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  
  
  spec.add_runtime_dependency 'autoprefixer-rails', '~> 9.1', '>= 9.1.0'
end
