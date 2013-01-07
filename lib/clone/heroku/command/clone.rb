require 'heroku/command/base'
require 'securerandom'

class Heroku::Command::Clone < Heroku::Command::Base

  # clone:create [NAME]
  #
  # Create a new app which is a clone of an existing app
  #
  #     --addons ADDONS        # a comma-delimited list of addons to install
  # -a, --app APP              # the app which should be cloned
  # -b, --buildpack BUILDPACK  # a buildpack url to use for this app
  # -n, --no-remote            # don't create a git remote
  # -r, --remote REMOTE        # the git remote to create, default "heroku"
  # -s, --stack STACK          # the stack on which to create the app
  # -c, --no-collabs           # don't copy over the collaborators
  # -v, --no-vars              # don't copy over the config vars
  # -f, --no-features          # don't copy over the labs features
  #
  #Examples:
  #
  # $ heroku clone:create
  # Creating floating-dragon-42-clone-e153d5... done, stack is cedar
  # http://floating-dragon-42.heroku.com/ | git@heroku.com:floating-dragon-42.git
  #
  # $ heroku clone:create -s bamboo
  # Creating floating-dragon-42-clone-e153d5... done, stack is bamboo-mri-1.9.2
  # http://floating-dragon-42.herokuapp.com/ | git@heroku.com:floating-dragon-42.git
  #
  # # specify a name
  # $ heroku clone:create example
  # Creating example... done, stack is cedar
  # http://example.heroku.com/ | git@heroku.com:example.git
  #
  # # create a staging app
  # $ heroku clone:create example-staging --remote staging
  #
  def create
    apps_command.create

    unless options[:no_collabs].is_a? FalseClass
      sharing
    end

    unless options[:no_vars].is_a? FalseClass
      config
    end

    unless options[:no_features].is_a? FalseClass
      features
    end
  end

  # clone:sharing NAME
  #
  # Copy the list of collaborators of one app to another app
  #
  # -a, --app APP              # app whose collaborators should be copied
  #
  #Examples:
  #
  # $ heroku clone:sharing example-clone -a example
  # Copying collaborator@example.com to example-clone collaborators
  #
  def sharing
    collaborators = api.get_collaborators(app).body.map{|collab| collab['email']}
    target_collaborators = api.get_collaborators(target_app).body.map{|collab| collab['email']}

    (collaborators - target_collaborators).each do |email|
      action("Copying #{email} to #{target_app} collaborators") do
        api.post_collaborator(target_app, email)
      end
    end
  end

  # clone:config NAME
  #
  # Copy the config of one app to another app
  #
  # -a, --app APP              # app whose config should be copied
  #
  #Examples:
  #
  # $ heroku clone:config example-clone -a example
  # Copying config vars from example and restarting example-clone
  #
  def config
    vars = api.get_config_vars(app).body

    action("Copying config vars from #{app} and restarting #{target_app}") do
      api.put_config_vars(target_app, vars)

      @status = begin
        if release = api.get_release(target_app, 'current').body
          release['name']
        end
      rescue Heroku::API::Errors::RequestFailed => e
      end
    end
  end

  # clone:features NAME
  #
  # Copy the features of one app to another app
  #
  # -a, --app APP              # app whose features should be copied
  #
  #Examples:
  #
  # $ heroku clone:features example-clone -a example
  # Adding user_env_compile to example-clone
  # Deleting sigterm-all from example-clone
  #
  def features
    features = Hash[api.get_features(app).body.map{|feature| [feature['name'], feature['enabled']]}]
    actual_features = Hash[api.get_features(target_app).body.map{|feature| [feature['name'], feature['enabled']]}]

    features_to_enable = features.select{|feature, enabled| enabled && !actual_features[feature]}
    features_to_disable = actual_features.select{|feature, enabled| enabled && !features[feature]}

    action("Copying labs features from #{app} and restarting #{target_app}") do
      features_to_enable.each do |feature|
        puts "Adding #{feature} to #{target_app}"
        api.post_feature(feature, target_app)
      end

      features_to_disable.each do |feature|
        puts "Deleting #{feature} from #{target_app}"
        api.delete_feature(feature, target_app)
      end
    end
  end

  private

  def apps_command
    @apps_command ||= Heroku::Command::Apps.new(@args, @options.merge(app: target_app))
  end

  def target_app
    @target_app ||= shift_argument || "#{app}-clone-#{SecureRandom.hex(2)}"
  end

end