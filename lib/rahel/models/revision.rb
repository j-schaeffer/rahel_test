# 2014-08-04 marius.gawrisch@gmail.com

module Rahel
  class Revision < ActiveRecord::Base
    belongs_to :user
    belongs_to :subject, class_name: "Individual"

    def self.create_from_new_individual indi, user=nil
      rev = self.new
      rev.set_new_individual indi
      rev.user = user if user
      rev.save
    end

    def self.create_from_new_property prop, user=nil
      rev = self.new
      rev.set_new_property prop
      rev.user = user if user
      rev.save
    end

    def self.create_from_old_property prop, user=nil
      rev = self.new
      rev.set_old_property prop
      rev.user = user if user
      rev.save
    end

    def set_old_individual indi
      self.old_individual_id = indi.id
      self.individual_type   = indi.type
      self.old_label         = indi.label
    end

    def set_new_individual indi
      self.new_individual_id = indi.id
      self.individual_type   = indi.type
      self.new_label         = indi.label
    end

    def set_old_property prop
      self.property_id   = prop.id
      self.property_type = prop.type
      self.subject_id    = prop.subject.id
      self.subject_label = prop.subject.label
      self.subject_type  = prop.subject.type
      self.predicate     = prop.predicate

      if prop.objekt_id
        self.old_objekt_id    = prop.objekt_id
        self.old_objekt_label = prop.objekt.label
        self.old_objekt_type  = prop.objekt.type
      end

      self.old_data       = prop.data
      self.old_data_text  = prop.data_text
      self.old_data_int   = prop.data_int
      self.old_data_float = prop.data_float
      self.old_data_bool  = prop.data_bool
      self.old_data_date  = prop.data_date
    end

    def set_new_property prop
      self.property_id   = prop.id
      self.property_type = prop.type
      self.subject_id    = prop.subject.id
      self.subject_label = prop.subject.label
      self.subject_type  = prop.subject.type
      self.predicate     = prop.predicate

      if prop.objekt_id
        self.new_objekt_id    = prop.objekt_id
        self.new_objekt_label = prop.objekt.label
        self.new_objekt_type  = prop.objekt.type
      end

      self.new_data       = prop.data
      self.new_data_text  = prop.data_text
      self.new_data_int   = prop.data_int
      self.new_data_float = prop.data_float
      self.new_data_bool  = prop.data_bool
      self.new_data_date  = prop.data_date
    end

    def old_value
      old_objekt_label || old_objekt_id || old_data || old_data_text || old_data_int ||
        old_data_float || old_data_bool || old_data_date
    end

    def new_value
      new_objekt_label || new_objekt_id || new_data || new_data_text || new_data_int ||
        new_data_float || new_data_bool || new_data_date
    end

    def to_s
      if property_id
        if old_value && new_value
          "M. Gawrisch hat den/die/das #{I18n.t "#{subject_type}.#{predicate}"} " +
            "bei #{subject_label} von „#{old_value}“ zu „#{new_value}“ geändert."
        elsif new_value
          "M. Gawrisch hat den/die/das #{I18n.t "#{subject_type}.#{predicate}"} " +
            "„#{new_value}“ zu #{subject_label} hinzugefügt."
        else
          "M. Gawrisch hat den/die/das #{I18n.t "#{subject_type}.#{predicate}"} " +
            "„#{old_value}“ von #{subject_label} entfernt."
        end
      else
        if old_individual_id && new_individual_id
          "M. Gawrisch hat ein/e #{I18n.t "types.#{individual_type}"} von „#{old_label}“ " +
            "zu „#{new_label}“ umbenannt."
        elsif new_label
          "M. Gawrisch hat den/die/das #{I18n.t "types.#{individual_type}"} #{new_label} erstellt."
        else
          "M. Gawrisch hat den/die/das #{I18n.t "types.#{individual_type}"} #{old_label} gelöscht."
        end
      end
    end
  end
end
