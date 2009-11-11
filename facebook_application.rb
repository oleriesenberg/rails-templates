run "rm public/index.html"

file ".gitignore",
%q{log/*
tmp/*
.tmp*
db/*.db
db/*.sqlite3
.loadpath
.project
.DS_Store
}

plugin 'exception_notification', :git => 'git://github.com/rails/exception_notification.git'

rake("db:sessions:create") if yes?("\n\nUse ActiveRecord session store?")

file "db/migrate/20090903145559_create_users.rb",
%q{class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.integer :facebook_id, :limit => 8, :null => false
      t.string :session_key
      t.timestamps
    end
    add_index :users, :facebook_id
  end

  def self.down
    drop_table :users
  end
end
}

plugin 'facebooker', :git => 'git://github.com/mmangino/facebooker.git'

file "app/controllers/application_controller.rb",
%q{class ApplicationController < ActionController::Base
  include ExceptionNotifiable
  helper :all

  skip_before_filter :verify_authenticity_token

  ensure_application_is_installed_by_facebook_user
  ensure_authenticated_to_facebook
  filter_parameter_logging :fb_sig_friends

  attr_accessor :current_user
  helper_attr :current_user
  before_filter :set_current_user

  def set_current_user
    set_facebook_session
    # if the session isn't secured, we don't have a good user id
    if facebook_session and 
       facebook_session.secured? and 
       !request_is_facebook_tab?
      self.current_user = User.for(facebook_session.user.to_i, facebook_session) 
    end
  end
end
}

file "app/models/user.rb",
%q{class User < ActiveRecord::Base
  def self.for(facebook_id,facebook_session=nil)
    returning find_or_create_by_facebook_id(facebook_id) do |user|
      unless facebook_session.nil?
        user.store_session(facebook_session.session_key) 
      end
    end
  end

  def store_session(session_key)
    if self.session_key != session_key
      update_attribute(:session_key, session_key) 
    end
  end
  
  def facebook_session
    @facebook_session ||=
      returning Facebooker::Session.create do |session|
        session.secure_with!(session_key, facebook_id, 1.day.from_now)
        Facebooker::Session.current=session
    end
  end
end
}