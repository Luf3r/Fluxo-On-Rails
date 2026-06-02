class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  before_create :assign_uuid_v7_primary_key

  private

  def assign_uuid_v7_primary_key
    return unless self.class.primary_key == "id"
    return unless has_attribute?(self.class.primary_key)
    return unless self.class.type_for_attribute(self.class.primary_key).type == :uuid

    self.id ||= SecureRandom.uuid_v7
  end
end
