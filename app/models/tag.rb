# A tag of an inventory pool ("Etiquetado", "Revisar", ...) that its staff
# put on items, to see them in the inventory list and filter by them.
class Tag < ApplicationRecord
  # colors of new tags, in turn
  COLORS = %w(#e4572e #2e86ab #3bb273 #f3a712 #8e44ad #6c757d).freeze

  belongs_to :inventory_pool
  has_and_belongs_to_many :items

  validates :name, presence: true
  validates :name, uniqueness: { scope: :inventory_pool_id, case_sensitive: false }
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }

  before_validation do
    self.name = name.to_s.strip
    # NOTE: a new tag comes with the default color of the column
    if new_record? and not color_changed? and inventory_pool
      self.color = COLORS[inventory_pool.tags.count % COLORS.size]
    end
  end

  def as_json(_options = {})
    { id: id, name: name, color: color }
  end
end
