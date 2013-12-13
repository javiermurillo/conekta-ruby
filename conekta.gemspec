$:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'conekta/version'

spec = Gem::Specification.new do |s|
  s.name = 'conekta'
  s.version = Conekta::VERSION
  s.summary = 'Ruby bindings for the Conekta API'
  s.description = 'Easy payments and shipping, see http://conekta.mx for details.'
  s.authors = ['Leo Fischer', 'Mauricio Murga']
  s.email = %w(leo@conekta.mx mauricio@conekta.com)
  s.homepage = 'http://conekta.mx/doc'

  s.add_dependency('rest-client', '~> 1.4')
  s.add_dependency('multi_json', '>= 1.0.4', '< 2')

#  s.add_development_dependency('mocha', '~> 0.13.2')
  s.add_development_dependency('shoulda', '~> 3.4.0')
#  s.add_development_dependency('test-unit')
  s.add_development_dependency('rspec')
  s.add_development_dependency('rake')

  s.files = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
end
