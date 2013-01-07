require 'spec_helper'
require 'clone/heroku/command/apps'

describe Heroku::Command::Apps do

  before do
    Heroku::Command::Apps.any_instance.stub(:api => heroku)
  end

  let(:new_app_name) { SecureRandom.hex(8) }

  it 'cannot clone a non-existing app' do
    with_app do |app_data|
      proc{ execute("apps:clone -a non-existing") }.should raise_error
    end
  end

  it 'can clone an existing app' do
    with_app do |app_data|
      proc{ execute("apps:clone -a #{app_data['name']}") }.should_not raise_error
    end
  end

  it 'creates app with specified name' do
    with_app do |app_data|
      execute("apps:clone #{new_app_name} -a #{app_data['name']}")
      heroku.get_app(new_app_name).body['name'].should == new_app_name
    end
  end

  it 'uses the same stack' do
    with_app do |app_data|
      execute("apps:clone #{new_app_name} -a #{app_data['name']}")
      new_app = heroku.get_app(new_app_name)

      new_app.body['stack'].should eql( app_data['stack'] )
    end
  end

  it 'uses the stack option if it is provided' do
    with_app do |app_data|
      execute("apps:clone #{new_app_name} -s cedar -a #{app_data['name']}")
      new_app = heroku.get_app(new_app_name)

      new_app.body['stack'].should eql( "cedar" )
    end
  end

  it 'uses the same collaborators' do
    with_app do |app_data|
      execute("apps:clone #{new_app_name} -a #{app_data['name']}")

      app_collaborators = heroku.get_collaborators( app_data['name'] ).body.map{|collab| collab['email']}
      new_app_collaborators = heroku.get_collaborators( new_app_name ).body.map{|collab| collab['email']}

      (app_collaborators - new_app_collaborators).should be_empty
    end
  end

  it 'skips copying the collaborators when option is set' do
    with_app do |app_data|
      execute("apps:clone #{new_app_name} -a #{app_data['name']} -c")

      app_collaborators = heroku.get_collaborators( app_data['name'] ).body.map{|collab| collab['email']}
      new_app_collaborators = heroku.get_collaborators( new_app_name ).body.map{|collab| collab['email']}

      (app_collaborators - new_app_collaborators).should_not be_empty
    end
  end

  it 'clones the config variables' do
    with_app do |app_data|
      execute("apps:clone #{new_app_name} -a #{app_data['name']}")

      config_vars = heroku.get_config_vars(app_data['name']).body
      new_config_vars = heroku.get_config_vars(new_app_name).body

      (config_vars.to_a - new_config_vars.to_a).should be_empty
    end
  end

  it 'skips cloning the config variables when option is set' do
    with_app do |app_data|
      execute("apps:clone #{new_app_name} -a #{app_data['name']} -v")

      config_vars = heroku.get_config_vars(app_data['name']).body
      new_config_vars = heroku.get_config_vars(new_app_name).body

      (config_vars.to_a - new_config_vars.to_a).should_not be_empty
    end
  end

end