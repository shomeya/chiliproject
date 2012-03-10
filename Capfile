load 'deploy'
# Uncomment if you are using Rails' asset pipeline
    # load 'deploy/assets'
Dir['vendor/gems/*/recipes/*.rb','vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load 'config/deploy' # remove this line to skip loading any of the default tasks

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