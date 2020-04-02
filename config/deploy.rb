require 'mina/rails'
require 'mina/git'
require 'mina/rbenv'
require 'mina/puma'
require 'mina_sidekiq/tasks'

set :application_name, 'project_app'

task :staging do
  set :rails_env, 'staging'
  set :domain,    '127.0.0.1'
  set :user,      'app'
  set :branch,    'master'
end

task :production do
  set :rails_env, 'production'
  set :domain,    '127.0.0.1'
  set :user,      'app'
  set :branch,    'master'
end

set :deploy_to,  '/var/www/project_app/public_html'
set :repository, 'git@github.com:nguyenthanhcong101096/mina_rails.git'

set :port, '22'
set :forward_agent, true

set :shared_files, ['config/database.yml', 'config/master.key', ".env.#{fetch(:rails_env)}"]
set :shared_dirs, ['log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'bundle', 'public/packs', 'config/puma', 'node_modules', 'public/uploads']

set :bundle_bin,  "#{fetch(:rbenv_path)}/bin/rbenv exec bundle"
set :bundle_path, "#{fetch(:shared_path)}/bundle"

set :puma_config, "#{fetch(:shared_path)}/config/puma/#{fetch(:rails_env)}.rb"

set :sidekiq_log, "#{fetch(:shared_path)}/log/sidekiq.log"
set :sidekiq_pid, "#{fetch(:shared_path)}/tmp/pids/sidekiq.pid"

task :remote_environment do
  invoke :'rbenv:load'
end

task :setup do
end

desc 'Deploys the current version to the server.'
task :deploy do
  # uncomment this line to make sure you pushed your local branch to the remote origin
  # invoke :'git:ensure_pushed'
  deploy do
    invoke :'git:clone'
    # invoke :'sidekiq:quiet'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'
    invoke :'deploy:cleanup'

    on :launch do
      # invoke :'sidekiq:restart'
      invoke :'puma:hard_restart'
    end
  end
end

task :upload_file do
  run(:local) do
    command "scp package.json                        #{fetch(:user)}@#{fetch(:domain)}:#{fetch(:shared_path)}/package.json"
    command "scp config/master.key                   #{fetch(:user)}@#{fetch(:domain)}:#{fetch(:shared_path)}/config/master.key"
    command "scp config/database.yml                 #{fetch(:user)}@#{fetch(:domain)}:#{fetch(:shared_path)}/config/database.yml"
    command "scp .env.#{fetch(:rails_env)}           #{fetch(:user)}@#{fetch(:domain)}:#{fetch(:shared_path)}/.env.#{fetch(:rails_env)}"
    command "scp config/puma/#{fetch(:rails_env)}.rb #{fetch(:user)}@#{fetch(:domain)}:#{fetch(:shared_path)}/config/puma/#{fetch(:rails_env)}.rb"
  end

  run(:local) do
    command 'say "Done!"'
  end
end

task :log do
  in_path(fetch(:deploy_to)) do
    command "tail -f shared/log/#{fetch(:rails_env)}.log"
  end
end

task :console do
  in_path(fetch(:current_path)) do
    command %{#{fetch(:rails)} console}
  end
end

namespace :db do
  desc 'Seed the database.'
  task :seed do
    in_path(fetch(:current_path)) do
      command "RAILS_ENV=#{fetch(:rails_env)} #{fetch(:bundle_bin)} exec rake db:seed"
    end
  end

  desc 'Migrate database'
  task :migrate do
    in_path(fetch(:current_path)) do
      command "RAILS_ENV=#{fetch(:rails_env)} #{fetch(:bundle_bin)} exec rake db:migrate"
    end
  end

  desc 'Reset database'
  task :reset do
    in_path(fetch(:current_path)) do
      command "RAILS_ENV=#{fetch(:rails_env)} #{fetch(:bundle_bin)} exec rake db:drop db:create"
    end
  end
end