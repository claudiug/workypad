#TODO change integer ID to UUID
class Job < ApplicationRecord
  include RankedModel
  ranks :order,
    with_same: :user_id

  has_rich_text :listing

  attr_accessor :position

  enum status: { research: 0, applied: 1, interview: 2, test: 3, offer: 4, archived: 5 }
  enum mode: { office: 1, hybrid: 2, remote: 3, other: 9 }
  enum arrangement: { not_set: 1, full_time: 2, contract: 3, contract_to_hire: 4, freelance: 5, internship: 6}

  belongs_to :user
  belongs_to :source, optional: true
  has_many :notes, dependent: :destroy

  validates :entity, presence: true, unless: -> (obj){ obj.agency.present? }
  validates :agency, presence: true, unless: -> (obj){ obj.entity.present? }
  validates :title, :status, presence: true

  # before_create :add_initial_order!
  before_save :update_status_updated_at!, if: ->(obj){ !obj.persisted? || obj.will_save_change_to_status? }
  before_save :update_applied_at!, if: ->(obj){ obj.status_changed?(to: 'applied') }
  before_save :update_archived_at!, if: ->(obj){ obj.status_changed?(to: 'archived') }
  after_save :create_applied_note!, if: -> (obj){obj.status_previously_changed?(to: 'applied')}
  after_save :create_archived_note!, if: -> (obj){obj.status_previously_changed?(to: 'archived')}


  def add_initial_order!
    self.order = (self.user.jobs.order(:order)&.last&.order || 0) + 1
  end

  def reorder_up!
    self.update order_position: :up
    self
  end

  def reorder_down!
    self.update order_position: :down
    self
  end

  def days_since_last_note?
    if notes.any?
      exact_days_since_last_note?.floor
    else
      nil
    end
  end

  def exact_days_since_last_note?
    if notes.any?
      (Time.now - notes.order(:created_at).last.created_at).to_f/1.day
    else
      nil
    end
  end

  def card_color?
    if days_since_last_note?.nil?
      'bg-white'
    elsif days_since_last_note? < 2
      'bg-red-200'
    elsif days_since_last_note? < 5
      'bg-red-100'
    elsif days_since_last_note? < 9
      'bg-white'
    elsif days_since_last_note? < 15
      'bg-blue-100'
    elsif days_since_last_note? < 20
      'bg-blue-200'
    else
      'bg-blue-300'
    end

  end

  private

  def update_status_updated_at!
    self.status_updated_at = Time.now
  end

  def update_applied_at!
    self.applied_at = Date.today
  end

  def create_applied_note!
    self.notes.applied.create(content: "Applied")
  end

  def update_archived_at!
    self.archived_at = Date.today
  end

  def create_archived_note!
    self.notes.archive.create(content: "Archived")
  end
end

