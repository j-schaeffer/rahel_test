# Rahel: Property
# 2014-01-12 martin.stricker@gmail.com 

module Rahel
  class Property < ActiveRecord::Base
    belongs_to :subject, inverse_of: :properties, class_name: "Rahel::Individual"

    validate :valid_subject?

    # Callbacks
    before_save :before_save_actions
    after_destroy :after_destroy_actions

    # Konstruktor für alle Property Klassen
    def self.property_create(subject, predicate, objekt)
      p = self.new
      p.subject = subject
      p.predicate = predicate
      p.value = objekt
      p.save
      p
    end

    def valid_subject?
      # Da subject.predicate nicht das selbe Objekt wie dieses ist,
      # und somit subject.valid? die Validität anhand der Daten aus der
      # Datenbank prüft, muss der Property, die dieser entspricht und am
      # subject hängt, explizit der aktuelle (ggf. nicht in der DB gespeicherte)
      # Wert zugewiesen werden, um die Validität vom Subject prüfen zu können.
      # (Nur wenn prop bereits in DB war)
      if id
        subject.sorted_properties(predicate).find { |p| p.id == id }.value = value
        subject.valid?
      end
    end

    # Attribute Write value
    # :string (Default)
    # Für :string-Properties jedoch Klasse Rahel::PropertyString wählen!
    def value=(value)
      self.data = value.to_s.strip
    end
    
    # Attribute Read value
    # :string
    def value
      data
    end
    
    # Attribute Read value for Sort
    def sort_value
      value
    end
    
    def index_value
      value
    end

    # Property Type
    # :string
    def property_type
      :undefined
    end

    def cardinality
      # kann nil sein
      subject.predicates[predicate][:cardinality]
    end

    def editable?
      # Objekt-Properties sind naturgemäß immer editierbar.
      property_type != :objekt || subject.predicates[predicate][:editable]
    end

    def join?
      subject.predicates[predicate][:join]
    end

    def cached?
      subject.predicates[predicate][:cached]
    end

    def range
      subject.predicates[predicate][:range]
    end

    def options
      subject.predicates[predicate][:options]
    end

    # Wird in PropertyObjekt überschrieben
    def inverse
      nil
    end

    def objekt?
      property_type == :objekt
    end
    
    # returns the default_value for this Property, if a default value for this
    # Property is set in its owner Individual, nil otherwise
    def default_value
      begin
        self.subject.predicates[self.predicate][:default]
      rescue
        nil
      end
    end

    private

    def before_save_actions
      # Wenn dieses Property gecached werden soll, dann das tun.
      if cached?
        subject.send("#{predicate}_cache=", value)
        subject.save
      end
    end
    
    def after_destroy_actions
      # Wenn diese Property gecached war, dann den beim Löschen der Property Cache leeren
      if cached?
        subject.send("#{predicate}_cache=", nil)
        subject.save
      end    
    end
  end
end
