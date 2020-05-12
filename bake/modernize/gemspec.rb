
# Rewrite the current gemspec.
def gemspec
	path = self.default_gemspec_path
	buffer = StringIO.new
	
	update(path: path, output: buffer)
	
	File.write(path, buffer.string)
end

# Rewrite the specified gemspec.
# @param
def update(path: self.default_gemspec_path, output: $stdout)
	spec = Gem::Specification.load(path)
	
	root = File.dirname(path)
	version_path = self.version_path(root)
	
	constant = File.read(version_path)
		.scan(/module\s+(.*?)$/)
		.flatten
		.join("::")
	
	spec.metadata["funding_uri"] ||= detect_funding_uri(spec)
	spec.metadata["documentation_uri"] ||= detect_documentation_uri(spec)
	
	spec.metadata.delete_if{|_, value| value.nil?}
	
	output.puts
	output.puts "require_relative #{version_path.sub(/\.rb$/, '').inspect}"
	output.puts
	output.puts "Gem::Specification.new do |spec|"
	output.puts "\tspec.name = #{spec.name.dump}"
	output.puts "\tspec.version = #{constant}::VERSION"
	output.puts "\t"
	output.puts "\tspec.summary = #{spec.summary.inspect}"
	output.puts "\tspec.authors = #{spec.authors.inspect}"
	output.puts "\tspec.license = #{spec.license.inspect}"
	
	if spec.homepage and !spec.homepage.empty?
		output.puts "\t"
		output.puts "\tspec.homepage = #{spec.homepage.inspect}"
	end
	
	if spec.metadata.any?
		output.puts "\t"
		output.puts "\tspec.metadata = {"
		spec.metadata.sort.each do |key, value|
			output.puts "\t\t#{key.inspect} => #{value.inspect},"
		end
		output.puts "\t}"
	end
	
	output.puts "\t"
	output.puts "\tspec.files = #{directory_glob_for(spec)}"
	
	if spec.require_paths != ['lib']
		output.puts "\tspec.require_paths = ['lib']"
	end
	
	if executables = spec.executables and executables.any?
		output.puts "\t"
		output.puts "\tspec.executables = #{executables.inspect}"
	end
	
	if extensions = spec.extensions and extensions.any?
		output.puts "\t"
		output.puts "\tspec.extensions = #{extensions.inspect}"
	end
	
	if required_ruby_version = spec.required_ruby_version
		output.puts
		output.puts "\tspec.required_ruby_version = #{required_ruby_version.to_s.inspect}"
	end
	
	if spec.dependencies.any?
		output.puts "\t"
		spec.dependencies.sort.each do |dependency|
			next unless dependency.type == :runtime
			output.puts "\tspec.add_dependency #{format_dependency(dependency)}"
		end
	end
	
	if spec.development_dependencies.any?
		output.puts "\t"
		spec.development_dependencies.sort.each do |dependency|
			output.puts "\tspec.add_development_dependency #{format_dependency(dependency)}"
		end
	end
	
	output.puts "end"
end

private

def directory_glob_for(spec, paths = spec.files)
	directories = {}
	root = File.dirname(spec.loaded_from)
	
	paths.each do |path|
		directory, _ = path.split(File::SEPARATOR, 2)
		
		full_path = File.expand_path(directory, root)
		if File.directory?(full_path)
			directories[directory] = true
		end
	end
	
	return "Dir['{#{directories.keys.join(',')}}/**/*', base: __dir__]"
end

def format_dependency(dependency)
	requirements = dependency.requirements_list
	
	if requirements.size == 1
		requirements = requirements.first
	end
	
	if requirements == ">= 0"
		requirements = nil
	end
	
	if dependency.name == "bundler"
		requirements = nil
	end
	
	if requirements
		"#{dependency.name.inspect}, #{requirements.inspect}"
	else
		"#{dependency.name.inspect}"
	end
end

def default_gemspec_path
	Dir["*.gemspec"].first
end

def version_path(root)
	Dir["lib/**/version.rb", base: root].first
end

require 'async'
require 'async/http/internet'

def valid_uri?(uri)
	Sync do
		internet = Async::HTTP::Internet.new
		response = internet.head(uri)
		
		next response.success?
	end
end

GITHUB_PROJECT = /github.com\/(?<account>.*?)\/(?<project>.*?)\/?/

def detect_funding_uri(spec)
	if match = spec.homepage.match(GITHUB_PROJECT)
		account = match[:account]
		
		funding_uri = "https://github.com/sponsors/#{account}/"
		
		if valid_uri?(funding_uri)
			return funding_uri
		end
	end
end

def detect_documentation_uri(spec)
	if match = spec.homepage.match(GITHUB_PROJECT)
		account = match[:account]
		project = match[:project]
		
		documentation_uri = "https://#{account}.github.io/#{project}/"
		
		if valid_uri?(documentation_uri)
			return documentation_uri
		end
	end
end
