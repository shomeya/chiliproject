require "bundler/capistrano"

set :application, "redmine"
set :repository,  "git@github.com:shomeya/chiliproject.git"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

role :web, "zoidberg.shomeya.com"                          # Your HTTP server, Apache/etc
role :app, "zoidberg.shomeya.com"                          # This may be the same as your `Web` server
role :db,  "zoidberg.shomeya.com", :primary => true        # This is where Rails migrations will run

set :deploy_to, "/var/www/apps/redmine"

set :user, "unicorn"
set :use_sudo, false
ssh_options[:keys] = ["#{ENV['HOME']}/.ssh/id_shomeya_engineering"]

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end