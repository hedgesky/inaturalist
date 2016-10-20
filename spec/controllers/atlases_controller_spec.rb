require File.dirname(__FILE__) + '/../spec_helper'

describe AtlasesController do
  describe "create" do
    it "should make an atlas belonging to the user" do
      user = User.make!
      atlas = Atlas.make!(user: user)
      expect(atlas.user_id).to eq user.id
    end
  end
end
