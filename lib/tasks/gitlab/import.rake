namespace :gitlab do
  namespace :import do
    # How to use:
    #
    #  1. copy your bare repos under git base_path
    #  2. run bundle exec rake gitlab:import:repos RAILS_ENV=production
    #
    # Notes:
    #  * project owner will be a first admin
    #  * existing projects will be skipped
    #
    desc "GITLAB | Import bare repositories from git_host -> base_path into GitLab project instance"
    task :repos => :environment do

      git_base_path = Gitlab.config.gitolite.repos_path
      repos_to_import = Dir.glob(git_base_path + '/*')

      namespaces = Namespace.pluck(:path)

      repos_to_import.each do |repo_path|
        repo_name = File.basename repo_path

        # Skip if group or user
        next if namespaces.include?(repo_name)

        # skip if not git repo
        next unless repo_name =~ /.git$/

        # skip gitolite admin
        next if repo_name == 'gitolite-admin.git'

        path = repo_name.sub(/\.git$/, '')

        project = Project.find_with_namespace(path)

        puts "Processing #{repo_name}".yellow

        if project
          puts " * #{project.name} (#{repo_name}) exists"
        else
          user = User.admins.first

          project_params = {
            :name => path,
            :namespace_id => Namespace.global_id,
            :issues_enabled => 0,
            :wall_enabled => 0,
            :merge_requests_enabled => 0,
            :wiki_enabled => 0,
          }

          project = Project.create_by_user(project_params, user)

          if project.valid?
            puts " * Created #{project.name} (#{repo_name})".green
          else
            puts " * Failed trying to create #{project.name} (#{repo_name})".red
          end
        end
      end

      puts "Done!".green
    end

    desc "GITLAB | Import user from ldap"
    task :create_user, [:login,:email] => :environment do |t, args|
      user = User.find_by_email args.email
      password = Devise.friendly_token[0, 8].downcase
      @user = User.new({
        extern_uid: 'CN=' + args.login + ',OU=Users,OU=Organic Units,DC=cern,DC=ch',
        provider: 'ldap',
        name: args.login,
        username: args.email.match(/^[^@]*/)[0],
        email: args.email,
        password: 'asdqwe123',
        password_confirmation: 'asdqwe123',
        projects_limit: Gitlab.config.gitlab.default_projects_limit,
      }, as: :admin)
      @user.blocked = false
      @user.save!
      @user
    end

  end
end
