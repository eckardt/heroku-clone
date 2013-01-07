require 'rspec'
require 'rr'
require 'tmpdir'
require 'heroku/cli'
require 'heroku-api'

module HerokuHelpers

  MOCK = ENV['MOCK'] != 'false'

  def data_site_crt
    @data_site_crt ||= File.read(File.join(DATA_PATH, 'site.crt'))
  end

  def data_site_key
    @data_site_key ||= File.read(File.join(DATA_PATH, 'site.key'))
  end

  def heroku
    # ENV['HEROKU_API_KEY'] used for :api_key
    Heroku::API.new(:mock => MOCK)
  end

  def random_domain
    "#{random_name}.com"
  end

  def random_name
    "akira-#{SecureRandom.hex(10)}"
  end

  def random_email_address
    "email@#{random_name}.com"
  end

  def random_params
    {
      'stack' => 'bamboo-mri-1.9.2',
    }
  end

  def with_app(params={}, &block)
    with_blank_git_repository do
      begin
        data = heroku.post_app(random_params.merge(params)).body
        @name = data['name']

        heroku.post_collaborator(@name, random_email_address)
        heroku.put_config_vars(@name, random_name.upcase => random_name)

        ready = false
        until ready
          ready = heroku.request(:method => :put, :path => "/apps/#{@name}/status").status == 201
        end
        yield(data)
      ensure
        heroku.delete_app(@name) rescue nil
      end
    end
  end

  def with_blank_git_repository(&block)
    sandbox = File.join(Dir.tmpdir, "heroku", Process.pid.to_s)
    FileUtils.mkdir_p(sandbox)

    old_dir = Dir.pwd
    Dir.chdir(sandbox)

    `git init`
    block.call

    FileUtils.rm_rf(sandbox)
  ensure
    Dir.chdir(old_dir)
  end

  def execute(command_line)
    extend RR::Adapters::RRMethods

    args = command_line.split(" ")
    command = args.shift

    Heroku::Command.load
    object, method = Heroku::Command.prepare_run(command, args)

    # any_instance_of(Heroku::Command::Base) do |base|
    #   stub(base).app.returns("example")
    # end

    stub(Heroku::Auth).get_credentials.returns(['email@example.com', 'apikey01'])
    stub(Heroku::Auth).api_key.returns('apikey01')

    original_stdin, original_stderr, original_stdout = $stdin, $stderr, $stdout

    $stdin  = captured_stdin  = StringIO.new
    $stderr = captured_stderr = StringIO.new
    $stdout = captured_stdout = StringIO.new
    class << captured_stdout
      def tty?
        true
      end
    end

    begin
      object.send(method)
    rescue SystemExit
    ensure
      $stdin, $stderr, $stdout = original_stdin, original_stderr, original_stdout
      Heroku::Command.current_command = nil
    end

    [captured_stderr.string, captured_stdout.string]
  end

end

RSpec.configure do |config|
  config.include HerokuHelpers
end