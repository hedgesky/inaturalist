require 'simplecov'
SimpleCov.start

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] = 'test'
require File.expand_path("../../config/environment", __FILE__)

require 'rspec/rails'
require 'capybara/rails'
require 'webmock/rspec'
WebMock.allow_net_connect!
require File.expand_path(File.dirname(__FILE__) + "/blueprints")
require File.expand_path(File.dirname(__FILE__) + "/helpers/make_helpers")
require File.expand_path(File.dirname(__FILE__) + "/helpers/example_helpers")
require File.expand_path(File.dirname(__FILE__) + "/../lib/eol_service.rb")
require File.expand_path(File.dirname(__FILE__) + "/../lib/meta_service.rb")
require File.expand_path(File.dirname(__FILE__) + "/../lib/flickr_cache.rb")

include MakeHelpers

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  #
  # == Notes
  #
  # For more information take a look at Spec::Runner::Configuration and Spec::Runner

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    Elasticsearch::Model.client.ping
  end

  config.before(:each) do
    DatabaseCleaner.start
    Delayed::Job.delete_all
    make_default_site
    CONFIG.has_subscribers = :disabled
  end

  config.after(:each) do
    DatabaseCleaner.clean
    CONFIG.has_subscribers = :enabled
  end
  
  config.before(:all) do
    DatabaseCleaner.clean_with(:truncation, { except: %w[spatial_ref_sys] })
    [PlaceGeometry, Observation, TaxonRange].each do |klass|
      begin
        Rails.logger.debug "[DEBUG] dropping enforce_srid_geom on place_geometries"
        ActiveRecord::Base.connection.execute("ALTER TABLE #{klass.table_name} DROP CONSTRAINT IF EXISTS enforce_srid_geom")
      rescue ActiveRecord::StatementInvalid 
        # already dropped
      end
      # ensure spatial_ref_sys has a vanilla WGS84 "projection"
      begin
        ActiveRecord::Base.connection.execute(<<-SQL
          INSERT INTO spatial_ref_sys VALUES (4326,'EPSG',4326,'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]', '+proj=longlat +datum=WGS84 +no_defs')
        SQL
        )
      rescue PG::Error, ActiveRecord::RecordNotUnique => e
        raise e unless e.message =~ /duplicate key/
      end
    end
  end

  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include RSpecHtmlMatchers
  config.include EsToggling
  config.extend EsTogglingHelper
  config.fixture_path = "#{::Rails.root}/spec/fixtures/"
  config.infer_spec_type_from_file_location!
  # disable certain specs. Useful for travis
  config.filter_run_excluding disabled: true
end

def without_delay
  Delayed::Worker.delay_jobs = false
  r = yield
  Delayed::Worker.delay_jobs = true
  r
end

def after_delayed_job_finishes
  r = yield
  Delayed::Worker.new.work_off
  r
end

# http://stackoverflow.com/questions/3768718/rails-rspec-make-tests-to-pass-with-http-basic-authentication
def http_login(user)
  request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(
    user.login, "monkey")
end

# inject a fixture check into API wrappers.  Need to stop making HTTP requests in tests
class EolService
  alias :real_request :request
  def request(method, *args)
    uri = get_uri(method, *args)
    fname = "#{uri.path}_#{uri.query}".gsub(/[\/\.]+/, '_').gsub( "&", "-" )
    fixture_path = File.expand_path(File.dirname(__FILE__) + "/fixtures/eol_service/#{fname}")
    if File.exists?(fixture_path)
      # puts "[DEBUG] Loading cached EOL response for #{uri}: #{fixture_path}"
      Nokogiri::XML(open(fixture_path))
    else
      cmd = "wget -O \"#{fixture_path}\" \"#{uri}\""
      # puts "[DEBUG] Couldn't find EOL response fixture, you should probably do this:\n #{cmd}"
      puts "Caching API response, running #{cmd}"
      system cmd
      real_request(method, *args)
    end
  end
end

class MetaService
  class << self
    alias :real_fetch_with_redirects :fetch_with_redirects
    def fetch_with_redirects( options, attempts = 3 )
      uri = options[:request_uri]
      fname = uri.to_s.parameterize
      fixture_path = File.expand_path( File.dirname( __FILE__ ) + "/fixtures/#{name.underscore}/#{fname}" )
      if File.exists?( fixture_path )
        # puts "[DEBUG] Loading cached API response for #{uri}: #{fixture_path}"
        # Nokogiri::XML(open(fixture_path))
        # OpenStruct.new(body: open(fixture_path).read )
        open( fixture_path ) do |f|
          return OpenStruct.new( body: f.read )
        end
      else
        cmd = "wget -O \"#{fixture_path}\" \"#{uri}\""
        # puts "[DEBUG] Couldn't find API response fixture, you should probably do this:\n #{cmd}"
        puts "Caching API response, running #{cmd}"
        system cmd
        real_fetch_with_redirects( options, attempts )
      end
    end
  end
end

class FlickrCache
  class << self
    alias :real_request :request
    def request( flickraw, type, method, params )
      fname = "flickr.#{ type }.#{ method }(#{ params })".gsub( /\W+/, "_" )
      fixture_path = File.expand_path( File.dirname( __FILE__ ) + "/fixtures/flickr_cache/#{fname}" )
      if File.exists?( fixture_path )
        # puts "[DEBUG] Loading FlickrCache for #{fname}: #{fixture_path}"
        return open( fixture_path ).read
      else
        response = real_request( flickraw, type, method, params )
        open( fixture_path, "w" ) do |f|
          f << response
          puts "Cached #{fixture_path}. Check it in to prevent this happening in the future."
        end
      end
    end
  end
end

# Change Paperclip storage from S3 to Filesystem for testing
LocalPhoto.attachment_definitions[:file].tap do |d|
  if d.nil?
    Rails.logger.warn "Missing :file attachment definition for LocalPhoto"
  elsif d[:storage] != :filesystem
    d[:storage] = :filesystem
    d[:path] = ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension"
    d[:url] = "/attachments/:class/:attachment/:id/:style/:basename.:extension"
    d[:default_url] = "/attachment_defaults/:class/:attachment/defaults/:style.png"
  end
end

# Override LocalPhoto processing so it always looks like it's done processing
class LocalPhoto
  def processing?
    false
  end
end

def make_default_site
  Site.make!(
    name: "iNaturalist",
    preferred_site_name_short: "iNat",
    preferred_email_noreply: "no-reply@inaturalist.org"
  ) unless Site.any?
  Site.default( refresh: true )
end

def enable_has_subscribers
  enable_elastic_indexing(UpdateAction)
  CONFIG.has_subscribers = :enabled
end

def disable_has_subscribers
  disable_elastic_indexing(UpdateAction)
  CONFIG.has_subscribers = :disabled
end
