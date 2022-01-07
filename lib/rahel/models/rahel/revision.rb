# 2014-08-04 marius.gawrisch@gmail.com

module Rahel
  class Revision < ActiveRecord::Base
    belongs_to :user
    belongs_to :subject, class_name: "Individual"
    belongs_to :old_individual, class_name: "Individual"
    belongs_to :new_individual, class_name: "Individual"
    belongs_to :old_objekt, class_name: "Individual"
    belongs_to :new_objekt, class_name: "Individual"
    belongs_to :occured_at_related_strong_individual, class_name: "Individual"
    belongs_to :other_related_strong_individual, class_name: "Individual"
    
    before_save :set_indexed, :set_creator_role, :set_action

    def self.create_from_new_individual indi, user, hide_on_global_list: false
      rev = self.new(hide_on_global_list: hide_on_global_list)
      rev.set_new_individual indi
      rev.user = user if user
      rev.set_strong_individual_fields
      rev.save
      rev
    end

    def self.create_from_old_individual indi, user, hide_on_global_list: false
      rev = self.new(hide_on_global_list: hide_on_global_list)
      rev.set_old_individual indi
      rev.user = user if user
      rev.set_strong_individual_fields
      rev.save
      rev
    end

    def self.create_from_new_property prop, user
      rev = self.new
      rev.set_new_property prop
      rev.user = user if user
      rev.set_strong_individual_fields
      rev.save
      rev
    end

    def self.create_from_old_property prop, user, hide_on_global_list: false, inverse: false
      rev = self.new(hide_on_global_list: hide_on_global_list, inverse: inverse)
      rev.set_old_property prop
      rev.user = user if user
      rev.set_strong_individual_fields
      rev.save
      rev
    end

    def set_old_individual indi
      self.old_individual_id = indi.id
      self.individual_type   = indi.type
      self.old_label         = indi.label
      self.visible_for       = indi.visibility
    end

    def set_new_individual indi
      self.new_individual_id = indi.id
      self.individual_type   = indi.type
      self.new_label         = indi.label
      self.visible_for       = indi.visibility
    end

    def set_old_property prop
      self.property_id   = prop.id
      self.property_type = prop.type
      self.subject_id    = prop.subject.id
      self.subject_label = prop.subject.label
      self.subject_type  = prop.subject.type
      self.visible_for   = prop.subject.visibility
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
      self.visible_for   = prop.subject.visibility
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

    # Feststellen, ob es sich um ein String-Property mit Options handelt,
    # das bei der Anzeige übersetzt werden soll.
    def translate
      return @translate if @translate != nil
      @translate = subject_type.constantize.predicates[predicate][:options] rescue false
    end

    def old_value
      return I18n.t(old_data) if old_data && translate

      old_objekt_label || old_objekt_id || old_data || old_data_text || old_data_int ||
        old_data_float || old_data_date || old_data_bool
    end

    def new_value
      return I18n.t(new_data) if new_data && translate

      new_objekt_label || new_objekt_id || new_data || new_data_text || new_data_int ||
        new_data_float || new_data_date || new_data_bool
    end

    def individual
      subject || old_individual || new_individual
    end

    # Brauchen dies zusätzlich zu "individual", da letzteres nil sein kann, obwohl eine id da ist
    # (nämlich wenn der individual inzwischen gelöscht wurde)
    def individual_id
      subject_id || old_individual_id || new_individual_id
    end

    def individual_label
      subject_label || old_label || new_label
    end

    def occured_at_individual
      if occured_at_related_strong_individual
        occured_at_related_strong_individual
      elsif individual
        if individual.weak?
          # Dieser Fall tritt auf, wenn es zwar eine occured_at_related_strong_individual_id
          # gibt, aber # dieser Individual schon gelöscht ist.
          nil
        else
          individual
        end
      else
        nil
      end
    end

    def occured_at_individual_id
      occured_at_related_strong_individual_id || individual_id
    end

    def occured_at_individual_label
      occured_at_related_strong_individual_label || individual_label
    end

    def h str
      ERB::Util.html_escape str
    end

    def to_s
      if property_id
        str = h(I18n.t(predicate)).to_str
        if new_data_bool
          # Boolean Properties brauchen eigenen Text
          str = "Als „#{str}“ markiert."
        elsif old_data_bool
          str = "Markierung als „#{str}“ entfernt."
        elsif old_value && new_value
          if subject_id != occured_at_individual_id
            str << " einer/s #{h I18n.t(occured_at_related_strong_individual_predicate)}"
          end
          str << " von „#{h old_value}“ zu „#{h new_value}“ geändert."
        elsif new_value
          if new_objekt && !new_objekt.weak?
            str << " <a href='#{new_objekt.path}'>#{h new_objekt_label}</a>"
          else
            if new_data_date
              str << " „#{h new_data_date.to_s(:ger_date)}“"
            else
              str << " „#{h new_value}“"
            end
          end
          if subject_id != occured_at_individual_id
            str << " zu #{h I18n.t(subject_type)}"
          end
          str << " hinzugefügt."
        else
          if old_objekt && !old_objekt.weak?
            str << " <a href='#{old_objekt.path}'>#{h old_objekt_label}</a>"
          else
            if old_data_date
              str << " „#{h old_data_date.to_s(:ger_date)}“"
            else
              str << " „#{h old_value}“"
            end
          end
          if subject_id != occured_at_individual_id
            str << " von #{h I18n.t(subject_type)}"
          end
          str << " entfernt."
        end

      else
        if old_individual_id && new_individual_id
          str = "Label von „#{h old_label}“ zu „#{h new_label}“ geändert."
        elsif new_individual_id
          str = "Datensatz erstellt."
        else
          str = "Datensatz gelöscht."
        end
      end
      str.html_safe
    end

    # occured_at_id ist der individual, auf dessen Seite die Änderung gemacht wurde, und unter dem
    # sie auf der globalen Revision-Liste auftauchen soll.
    # (Evtl. in "occured_at_id" umbenennen.)
    def set_strong_individual_fields occured_at_id: nil
      rr = individual.revision_receivers

      # Wenn ein Revision-Receiver selbst das Objekt der Revision ist, dann sollen
      # ausnahmsweise *keine* "related strong individuals" in die Revision eingetragen
      # werden. Grund: Es wird eine Revision für das inverse Property erstellt werden, die
      # schon auf der lokalen Revision-Liste angezeigt wird. Die Info ist somit schon da.
      return if rr.any? { |indi, _| indi.id == new_objekt_id }

      first_index = rr.index { |indi, _| indi.id.to_s == occured_at_id }

      if first_index
        self.occured_at_related_strong_individual_id        = rr[first_index][0].id
        self.occured_at_related_strong_individual_label     = rr[first_index][0].label
        self.occured_at_related_strong_individual_predicate = rr[first_index][1]
        rr.delete_at(first_index)
      elsif rr.any?
        self.occured_at_related_strong_individual_id        = rr[0][0].id
        self.occured_at_related_strong_individual_label     = rr[0][0].label
        self.occured_at_related_strong_individual_predicate = rr[0][1]
        rr.delete_at(0)
      end

      if rr.any?
        self.other_related_strong_individual_id        = rr[0][0].id
        self.other_related_strong_individual_predicate = rr[0][1]
        rr.delete_at(0)
      end

      if rr.any?
        # TODO Sagen, dass man noch third_related_strong_individual_id braucht
      end
    rescue
      # TODO Laut beschweren, falls development mode
    end

    # Vorm Speichern indexed wieder auf false setzen, damit die Revision beim nächsten
    # Delayed-Update vom Indexer wieder erfasst wird
    def set_indexed
      self.indexed = false
      # Gebe hier nil und nicht false zurück, da sonst die save-Action nicht
      # ausgeführt werden kann (Danke, Rails...)
      nil
    end
  
    # Beim Speichern der Revision automatisch die Rolle des Subjekts in creator_role cachen
    def set_creator_role
      # da die Spalte :creator_role erst kürzlich hinzukam und es noch ausstehende Migrations gibt,
      # in denen Revision.save aufgerufen wird (20160309154605_run_derive_tasks) muss hier vorerst
      # noch geprüft werden, ob die Spalte :creator_role überhaupt schon existiert. Sobald im master
      # in schema.rb diese Spalte vorhanden ist, kann "&& self.attribute_present?(:creator_role)"
      # entfernt werden
      if self.user.present? && self.has_attribute?(:creator_role)
        self.creator_role = self.user.role
      end
    end
    
    def set_action
      self.action = derive_action || self.action
    end
    
    # Versuche die Aktion der Revision daraus abzuleiten, welche Felder gesetzt sind.
    # Das funktioniert für die meisten allgemeinen Aktionen, wie das Hinzufügen einer 
    # Property zu einem Individual, nicht jedoch für spezielle Aktionen wie ein "send_invite", daher kann u.U. hier auch false zurückgegeben werden
    def derive_action
      # Revision bezieht sich auf eine Property
      # da new_value und old_value bei PropertyBools auch true/false sein können,
      # muss hier explizit auf nil geprüft werden
      if property_id
        if !new_value.nil? && !old_value.nil?
          "prop_update"
        elsif !new_value.nil?
          "prop_create"
        elsif !old_value.nil?
          "prop_delete"
        end
      # Revision bezieht sich direkt auf das Subjekt
      else
        if new_individual_id && old_individual_id
          "indi_rename"
        elsif new_individual_id
          "indi_create"
        elsif old_individual_id
          "indi_delete"
        else
          false
        end
      end
    end
  end
end
