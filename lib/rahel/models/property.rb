# Rahel: Property
# 2014-01-12 martin.stricker@gmail.com 

module Rahel
  class Property < ActiveRecord::Base
    belongs_to :subject, inverse_of: :properties, class_name: "Rahel::Individual"

    # Konstruktor für alle Property Klassen
    def self.property_create(subject, predicate, objekt)
      p = self.new
      p.subject = subject
      p.predicate = predicate
      p.value = objekt
      p.save
      p
    end

    # Attribute Write value
    # :string (Default)
    # Für :string-Properties jedoch Klasse Rahel::PropertyString wählen!
    def value=(value)
      self.data = value.to_s
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
    
    # Property Type
    # :string
    def property_type
      :string
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

    def range
      subject.predicates[predicate][:range]
    end

    # Wird in PropertyObjekt überschrieben
    def inverse
      nil
    end
  end
end
