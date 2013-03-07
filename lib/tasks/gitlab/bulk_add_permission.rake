namespace :gitlab do
  namespace :import do
    desc "GITLAB | Add a specific user to a specific project (as a developer)"
    task :cern_ldap_users_to_project, [:users,:project_path] => :environment  do |t, args|
      users_ids = Array.new
      usernames = args.users.split('@')
      usernames.each do|username|
	    id = User.where(:username => username).pluck(:id)
	    if not id.any?
	      passwd = Devise.friendly_token[0, 8].downcase
	      @user = User.new({
		  extern_uid: 'CN=' + username + ',OU=Users,OU=Organic Units,DC=cern,DC=ch',
	          provider: 'shibboleth',
	          name: username,
	          username: username,
	          email: username + '@cern.ch',
		  password: passwd,
		  password_confirmation: passwd,
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
	  if project.any?
		UsersProject.where(:project_id => project[0].id).each do |users_project|
		  if not users_ids.include?(users_project.user_id)
		    users_project.destroy
		  end
		end
		if users_ids.any?
		  projects_ids = Array.[](project[0].id)
		  UsersProject.add_users_into_projects(projects_ids, users_ids, UsersProject::DEVELOPER)
		end
	  end
    end
  end
end

