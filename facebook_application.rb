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

file "test/test_helper.rb",
%q{ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'flexmock/test_unit'

class ActiveSupport::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  #
  # The only drawback to using transactional fixtures is when you actually
  # need to test transactions.  Since your test is bracketed by a transaction,
  # any transactions started in your code will be automatically rolled back.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
}

file "test/unit/user_test.rb",
%q{require File.dirname(__FILE__) + '/../test_helper'

class UserTest < ActiveSupport::TestCase
  def test_for_creates_a_new_user
    e=User.count
    assert_not_nil User.for(2131231)
    assert_equal e+1,User.count
  end

  def test_for_returns_an_existing_user
    assert_equal users(:jen),User.for(users(:jen).facebook_id)
  end

  def test_for_sets_session_key_when_creating
    u=User.for(123123,flexmock(:session_key=>"ABC"))
    assert_equal "ABC",u.session_key
  end

  def test_for_updates_session_key
    u=User.for(123123,flexmock(:session_key=>"ABC"))
    u=User.for(123123,flexmock(:session_key=>"DEF"))
    assert_equal "DEF",u.reload.session_key
  end

  def test_will_create_facebook_session
    u=User.for(123123,flexmock(:session_key=>"ABC"))
    assert_not_nil u.facebook_session
    assert_equal "ABC",u.facebook_session.session_key
  end

end
}

file "test/fixtures/users.yml",
%q{mike:
  id: 1
  facebook_id: 12451752
jen:
  id: 2
  facebook_id: 123456
}




git :init
git :add => "."
git :commit => "-a -m 'Initial commit'"
