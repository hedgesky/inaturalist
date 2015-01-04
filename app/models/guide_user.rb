class GuideUser < ActiveRecord::Base
  attr_accessible :guide_id, :user_id
  belongs_to :guide, :inverse_of => :guide_users
  belongs_to :user, :inverse_of => :guide_users
end
