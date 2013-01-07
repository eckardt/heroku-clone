require 'heroku/command/base'
require 'securerandom'

class Heroku::Command::Apps < Heroku::Command::Base

  # apps:clone [NAME]
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
  #
  #Examples:
  #
  # $ heroku apps:clone
  # Creating floating-dragon-42-clone-e153d5... done, stack is cedar
  # http://floating-dragon-42.heroku.com/ | git@heroku.com:floating-dragon-42.git
  #
  # $ heroku apps:clone -s bamboo
  # Creating floating-dragon-42-clone-e153d5... done, stack is bamboo-mri-1.9.2
  # http://floating-dragon-42.herokuapp.com/ | git@heroku.com:floating-dragon-42.git
  #
  # # specify a name
  # $ heroku apps:clone example
  # Creating example... done, stack is cedar
  # http://example.heroku.com/ | git@heroku.com:example.git
  #
  # # create a staging app
  # $ heroku apps:clone example-staging --remote staging
  #
  def clone
    target_app = shift_argument || "#{app}-clone-#{SecureRandom.hex(2)}"
    source_app = app
    options[:app] = target_app

    create

    unless options[:no_collabs].is_a? FalseClass
      copy_collaborators(source_app, target_app)
    end

    unless options[:no_vars].is_a? FalseClass
      copy_config_vars(source_app, target_app)
    end
  end

  private

  def copy_collaborators(app, target_name)
    collaborators = api.get_collaborators(app).body.map{|collab| collab['email']}
    target_collaborators = api.get_collaborators(target_name).body.map{|collab| collab['email']}

    (collaborators - target_collaborators).each do |email|
      action("Copying #{email} to #{target_name} collaborators") do
        api.post_collaborator(target_name, email)
      end
    end
  end


  def copy_config_vars(app, target_name)
    vars = api.get_config_vars(app).body

    action("Copying config vars from #{app} and restarting #{target_name}") do
      api.put_config_vars(target_name, vars)

      @status = begin
        if release = api.get_release(target_name, 'current').body
          release['name']
        end
      rescue Heroku::API::Errors::RequestFailed => e
      end
    end
  end

end