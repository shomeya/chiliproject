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

$:.unshift(File.expand_path('./lib', ENV['rvm_path'])) # Add RVM's lib directory to the load path.
require "rvm/capistrano"                  # Load RVM's capistrano plugin.
set :rvm_ruby_string, 'ruby-1.9.2-p290@redmine'        # Or whatever env you want it to run in.


namespace :rvm do
  task :trust_rvmrc do
    run "rvm rvmrc trust #{release_path}"
  end
end
after "deploy", "rvm:trust_rvmrc"

namespace :deploy do

  desc "Create settings.php in shared/config" 
  task :after_setup do
    configuration = <<-EOF
# MySQL (default setup).

production:
  adapter: mysql
  database: chiliproject
  host: localhost
  username: root
  password:
  encoding: utf8

development:
  adapter: mysql
  database: chiliproject_development
  host: localhost
  username: root
  password:
  encoding: utf8

# Warning: The database defined as "test" will be erased and
# re-generated from your development database when you run "rake".
# Do not set this db to the same as development or production.
test:
  adapter: mysql
  database: chiliproject_test
  host: localhost
  username: root
  password:
  encoding: utf8

test_pgsql:
  adapter: postgresql
  database: chiliproject_test
  host: localhost
  username: postgres
  password: "postgres"

test_sqlite3:
  adapter: sqlite3
  database: db/test.sqlite3
EOF
    run "umask 02 && mkdir -p #{deploy_to}/#{shared_dir}/config"
    run "umask 02 && mkdir -p #{deploy_to}/#{shared_dir}/sockets"
    run "umask 02 && mkdir -p #{deploy_to}/#{shared_dir}/files"
    put configuration, "#{deploy_to}/#{shared_dir}/config/database.yml"
  end

  after 'deploy:setup', 'deploy:after_setup'


  desc "link pids, sockets, files dirs with release" 
  task :after_update_code do
    # link database settings
    run "rm -rf #{release_path}/config/database.yml"
    run "ln -nfs #{deploy_to}/#{shared_dir}/config/database.yml #{release_path}/config/database.yml"
    # setup pids and sockets directory
    run "rm -rf #{release_path}/tmp/pids"
    run "ln -nfs #{deploy_to}/#{shared_dir}/pids #{release_path}/tmp/pids"
    run "rm -rf #{release_path}/tmp/sockets"
    run "ln -nfs #{deploy_to}/#{shared_dir}/pids #{release_path}/tmp/sockets"
    # link file directory
    run "rm -rf #{release_path}/files"
    run "ln -nfs #{deploy_to}/#{shared_dir}/files #{release_path}/files"
  end
  
  after 'deploy:update', 'deploy:after_update_code'

  desc "restart unicorn" 
  task :upgrade_unicorn do
    run "/etc/init.d/unicorn-#{application} upgrade"
  end
  
  after 'deploy', 'deploy:upgrade_unicorn'


end