require 'spec_helper'
require 'clone/heroku/command/clone'

describe Heroku::Command::Clone do

  before do
    Heroku::Command::Base.any_instance.stub(:api => heroku)
  end

  let(:new_app_name) { SecureRandom.hex(8) }

  context "clone:create command" do

    it 'cannot clone a non-existing app' do
      with_app do |app_data|
        proc{ execute("clone:create -a non-existing") }.should raise_error
      end
    end

    it 'can clone an existing app' do
      with_app do |app_data|
        proc{ execute("clone:create -a #{app_data['name']}") }.should_not raise_error
      end
    end

    it 'creates app with specified name' do
      with_app do |app_data|
        execute("clone:create #{new_app_name} -a #{app_data['name']}")
        heroku.get_app(new_app_name).body['name'].should == new_app_name
      end
    end

    it 'uses the same stack' do
      with_app do |app_data|
        execute("clone:create #{new_app_name} -a #{app_data['name']}")
        new_app = heroku.get_app(new_app_name)

        new_app.body['stack'].should eql( app_data['stack'] )
      end
    end

    it 'uses the stack option if it is provided' do
      with_app do |app_data|
        execute("clone:create #{new_app_name} -s cedar -a #{app_data['name']}")
        new_app = heroku.get_app(new_app_name)

        new_app.body['stack'].should eql( "cedar" )
      end
    end

    it 'uses the same collaborators' do
      with_app do |app_data|
        execute("clone:create #{new_app_name} -a #{app_data['name']}")

        new_app_name.should have_same_collaborators(app_data['name'])
      end
    end

    it 'skips copying the collaborators when option is set' do
      with_app do |app_data|
        execute("clone:create #{new_app_name} -a #{app_data['name']} -c")

        new_app_name.should_not have_same_collaborators(app_data['name'])
      end
    end

    it 'clones the config variables' do
      with_app do |app_data|
        execute("clone:create #{new_app_name} -a #{app_data['name']}")

        new_app_name.should have_same_config(app_data['name'])
      end
    end

    it 'skips cloning the config variables when option is set' do
      with_app do |app_data|
        execute("clone:create #{new_app_name} -a #{app_data['name']} -v")

        new_app_name.should_not have_same_config(app_data['name'])
      end
    end

    it 'clones the labs features' do
      with_app do |app_data|
        err, out = execute("clone:create #{new_app_name} -a #{app_data['name']}")
        out.should include('Copying labs features')
      end
    end

    it 'skips cloning the labs features when option is set' do
      with_app do |app_data|
        err, out = execute("clone:create #{new_app_name} -a #{app_data['name']} -f")
        out.should_not include('Copying labs features')
      end
    end

  end

  context "clone:config command" do

    it 'cannot clone a non-existing app' do
      with_app do |app_data|
        proc{ execute("clone:config -a non-existing") }.should raise_error
      end
    end

    it 'requires an existing target app' do
      with_app do |app_data|
        proc{ execute("clone:config non-existing -a #{app_data['name']}") }.should raise_error
      end
    end

    it 'clones the config' do
      with_app do |app_data|
        with_app do |target_data|
          execute("clone:config #{target_data['name']} -a #{app_data['name']}")
          target_data['name'].should have_same_config(app_data['name'])
        end
      end
    end

  end

  context "clone:sharing command" do

    it 'cannot clone a non-existing app' do
      with_app do |app_data|
        proc{ execute("clone:sharing -a non-existing") }.should raise_error
      end
    end

    it 'requires an existing target app' do
      with_app do |app_data|
        proc{ execute("clone:sharing non-existing -a #{app_data['name']}") }.should raise_error
      end
    end

    it 'clones the collaborator list' do
      with_app do |app_data|
        with_app do |target_data|
          execute("clone:sharing #{target_data['name']} -a #{app_data['name']}")

          target_data['name'].should have_same_collaborators(app_data['name'])
        end
      end
    end

  end

  context "clone:features command" do

    it 'clones all labs features' do
      with_app do |app_data|
        with_app do |target_data|
          features = heroku.get_features(app_data['name']).body
          target_features = features.map(&:dup)
          features.detect{|feature| feature['name'] == 'sigterm-all'}.merge!('enabled' => false)
          features.detect{|feature| feature['name'] == 'user_env_compile'}.merge!('enabled' => true)

          heroku = stub('heroku api')
          heroku.stub(:get_features).with(app_data['name']).and_return(stub('response', body: features))
          heroku.stub(:get_features).with(target_data['name']).and_return(stub('response', body: target_features))
          Heroku::Command::Base.any_instance.stub(:api => heroku)

          heroku.should_receive(:post_feature).with(['user_env_compile', true], target_data['name'])
          heroku.should_receive(:delete_feature).with(['sigterm-all', true], target_data['name'])
          
          execute("clone:features #{target_data['name']} -a #{app_data['name']}")
        end
      end
    end

  end

  RSpec::Matchers.define :have_same_config do |expected|
    match do |actual|
      expected_vars = heroku.get_config_vars(expected).body
      actual_vars = heroku.get_config_vars(actual).body

      (expected_vars.to_a - actual_vars.to_a).empty?
    end
  end

  RSpec::Matchers.define :have_same_collaborators do |expected|
    match do |actual|
      expected_collaborators = heroku.get_collaborators( expected ).body.map{|collab| collab['email']}
      actual_collaborators = heroku.get_collaborators( actual ).body.map{|collab| collab['email']}

      (expected_collaborators - actual_collaborators).empty?
    end
  end

  RSpec::Matchers.define :have_labs_feature do |expected|
    match do |actual|
      heroku.get_feature( expected, actual ).body['enabled']
    end
  end

end