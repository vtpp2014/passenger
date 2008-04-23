require 'support/config'
require 'passenger/application_spawner'
require 'minimal_spawner_spec'
require 'spawn_server_spec'
require 'spawner_privilege_lowering_spec'
require 'spawner_error_handling_spec'
include Passenger

# TODO: write unit test which checks whether setting ENV['RAILS_ENV'] in environment.rb is respected (issue #6)

describe ApplicationSpawner do
	before :all do
		ENV['RAILS_ENV'] = 'production'
		@test_app = "stub/railsapp"
		Dir["#{@test_app}/log/*"].each do |file|
			File.chmod(0666, file) rescue nil
		end
		File.chmod(0777, "#{@test_app}/log") rescue nil
	end
	
	before :each do
		@spawner = ApplicationSpawner.new(@test_app)
		@spawner.start
		@server = @spawner
	end
	
	after :each do
		@spawner.stop
	end
	
	it_should_behave_like "a minimal spawner"
	it_should_behave_like "a spawn server"
	
	def spawn_application
		@spawner.spawn_application
	end
end

describe ApplicationSpawner do
	it_should_behave_like "handling errors in application initialization"
	
	def spawn_application(app_root)
		@spawner = ApplicationSpawner.new(app_root)
		begin
			@spawner.start
			return @spawner.spawn_application
		ensure
			@spawner.stop rescue nil
		end
	end
end

if Process.euid == ApplicationSpawner::ROOT_UID
	describe "ApplicationSpawner privilege lowering support" do
		before :all do
			@test_app = "stub/railsapp"
			ENV['RAILS_ENV'] = 'production'
		end
	
		it_should_behave_like "a spawner that supports lowering of privileges"
		
		def spawn_app(options = {})
			options = {
				:lower_privilege => true,
				:lowest_user => CONFIG['lowest_user']
			}.merge(options)
			@spawner = ApplicationSpawner.new(@test_app,
				options[:lower_privilege],
				options[:lowest_user])
			@spawner.start
			begin
				app = @spawner.spawn_application
				yield app
			ensure
				app.close
				@spawner.stop
			end
		end
	end
end
