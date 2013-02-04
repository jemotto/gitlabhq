namespace :gitlab do
  namespace :import do
    desc "GITLAB | Add all users to all projects (admin users are added as masters)"
    task :all_users_to_all_projects => :environment  do |t, args|
      user_ids = User.where(:admin => false).pluck(:id)
      admin_ids = User.where(:admin => true).pluck(:id)

      Project.find_each do |project|
        puts "Importing #{user_ids.size} users into #{project.code}"
        UsersProject.bulk_import(project, user_ids, UsersProject::DEVELOPER)
        puts "Importing #{admin_ids.size} admins into #{project.code}"
        UsersProject.bulk_import(project, admin_ids, UsersProject::MASTER)
      end
    end

    desc "GITLAB | Add a specific user to all projects (as a developer)"
    task :user_to_projects, [:email] => :environment  do |t, args|
      user = User.find_by_email args.email
      project_ids = Project.pluck(:id)

      UsersProject.user_bulk_import(user, project_ids, UsersProject::DEVELOPER)
    end

    desc "GITLAB | Add a specific user to a specific project (as a developer)"
    task :cern_ldap_users_to_project, [:users,:project_path] => :environment  do |t, args|
      users_ids = Array.new
      usernames = args.users.split('@')
      usernames.each do|username|
	    id = User.where(:username => username).pluck(:id)
	    if not id.any?
	      @user = User.new({
		      extern_uid: 'CN=' + username + ',OU=Users,OU=Organic Units,DC=cern,DC=ch',
	          provider: 'ldap',
	          name: username,
	          username: username,
	          email: username + '@cern.ch',
	          password: 'whatever',
	          password_confirmation: 'whatever',
	          projects_limit: Gitlab.config.gitlab.default_projects_limit,
	        }, as: :admin)
	      @user.blocked = false
	      @user.save!
	      @user
	      id = User.where(:username => username).pluck(:id)
        end
	    users_ids.concat(id);
      end
      project = Project.where(:path => args.project_path)
	  UsersProject.where(:project_id => project.id).each do |users_project|
	    if not users_ids.include?(users_project.user_id)
	      UsersProject.delete(users_project.id)
	    end
	  end
      if users_ids.any?
        UsersProject.bulk_import(project[0], users_ids, UsersProject::DEVELOPER)
      end
    end
  end
end

