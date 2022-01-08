# Rahel: Individuals

module Rahel
  class Individual < ActiveRecord::Base
    # ActiveRecord Setup
    has_many :properties, inverse_of: :subject, class_name: "Rahel::Property",
      foreign_key: :subject_id, dependent: :destroy
    # Die folgende Assoziation zurzeit in erster Linie für Lösch-Trigger (wenn Individual gelöscht wird,
    # so werden alle Properties, in denen es Objekt ist, entfernt)
    has_many :is_objekt, inverse_of: :objekt, class_name: "Rahel::PropertyObjekt",
      foreign_key: :objekt_id, dependent: :destroy
    # Callbacks
    before_save :before_save_actions

    default_scope { where(deleted: nil) }

    Rahel::OntologyBase.register_predicate(self, "label", :string, { cardinality: 1 })

    def self.inline_template path
      define_method :inline_template do
        path
      end
    end

    def self.property predicate, type, options={}

      # Names of Association & Attribute Methods & Property Class
      association_name = :"#{predicate}" # Access Property Object(s) (both)
      property_class = Rahel::OntologyBase.resolve_property_class type # Property Class (both)
      method_name_value_access = :"#{predicate}_value" # Access Property value (both)
      method_name_create_one = :"create_#{predicate}" # Create Property (has_one)
      method_name_set_one = :"#{predicate}=" # Set or Create Property (has_one)
      method_name_add_one = :"#{predicate}=" # Add Property (has_many)

      # Available options
      range = options[:range]
      inverse = options[:inverse]
      cardinality = options[:cardinality]

      # For Further Consideration
      Rahel::OntologyBase.register_predicate self, predicate, type, options

      # Lambda to check range and throw exception if out of range
      check_range = lambda do |val|
        if property_class == "Rahel::PropertyObjekt" && range
          unless (val.class.ancestors.select {|i| i.to_s[/#{range}/]}.length > 0)
            raise "Value #{val} with class #{val.class} is not in range #{range}"
          end
        end
      end

      # Associations & Attribute Methods
      if cardinality == 1

        # has_one
        has_one association_name, -> { where predicate: predicate }, class_name: property_class.to_s,
          foreign_key: :subject_id, dependent: :destroy

        # Accessing has_one value: individual#predicate_value
        define_method method_name_value_access do
          p = send(association_name)
          p ? p.value : nil
        end

        # Setting has_one value: individual#predicate=
        define_method method_name_set_one do |val=nil, set_inverse=true|
          p = send(association_name)
          # TODO method_name_set_one Wert von Property-Klasse validieren lassen
          if val == nil || val == ""
            if p
              p.inverse.destroy if p.inverse
              p.destroy
            end
            
            # Save ourselves (for Callbacks etc.)
            send(association_name, true)
            save

          else
            # Check range (raises exception if out of range)
            check_range.call(val)

            # Set value
            if p
              p.inverse.destroy if p.inverse
              p.value = val
              p.save
            else
              p = send(method_name_create_one, value: val)
            end

            # Save ourselves (for Callbacks etc.)
            save

            # Add/set value of inverse property if available and wanted
            val.send("#{inverse}=", self, false) if inverse && set_inverse
          end

          # Return the property, so the controller can create a revision
          p
        end
      else

        # has_many
        has_many association_name, -> { where predicate: predicate }, class_name: property_class.to_s,
          foreign_key: :subject_id, dependent: :destroy

        # Accessing has_many values: individual#predicate_value
        define_method method_name_value_access do
          send(association_name).map do |p|
            p.value
          end
        end

        # Adding to has_many one value: individual#predicate=
        define_method method_name_add_one do |val=nil, set_inverse=true|
          if val != nil && val != ""
            # Check range (raises exception if out of range)
            check_range.call(val)

            # Add value
            # TODO method_name_add_one Auf Duplikat überprüfen
            p = send(association_name).create(value: val)
            
            # Save ourselves (for Callbacks etc.)
            save
            
            # Add/set value of inverse property if available and wanted
            val.send("#{inverse}=", self, false) if inverse && set_inverse

            # Return the property, so the controller can create a revision
            p
          end
        end
      end
    end

    def self.edit_template path
      define_method :edit_template do
        path
      end
    end

    # Further Class Methods

    def self.predicates
      Rahel::OntologyBase.predicates self
    end

    def self.create options={}
      obj = super
      predicates.each do |property_name, options|
        default_value = options[:default]
        obj.send("#{property_name}=", default_value) if default_value != nil
      end
      obj
    end

    # Instance Methods

    def predicates
      self.class.predicates
    end
    
    def reset_defaults
      predicates.each do |property_name, options|
        default_value = options[:default]
        self.send("#{property_name}=", default_value) if default_value != nil
      end
    end
    
    # Values for Predicate
    def safe_values predicate, arrayify=true
      val = []
      if self.respond_to?(predicate.to_sym)
        val = send(predicate.to_sym)
        val = [val] unless val.respond_to?(:first)
        val = val.map do |a|
          a.value if a.respond_to?(:value)
        end
        val = val.map do |a|
          if(a.respond_to?(:label))
            a.label
          else
            a
          end
        end
      end
      if (arrayify==false && val.compact.empty?)
        nil
      else
        val.compact
      end
    end
    
    # First Safe Value
    def safe_value predicate, stringify=true
      val = (safe_values predicate).first
      if stringify == true
        val.to_s
      else
        val
      end
    end

    def to_s
      inline_label
    end
    
    def class_internal
      self.class.name
    end

    # Der Rückgabewert ist immer ein Array von Rahel::Properties.
    # Bei cardinality: 1 enthält es 1 Element.
    # TODO Macht das hier das gleiche wie „safe_values“?
    def get_sorted_properties_array predicate
      if predicate == "label"
        properties = [PropertyString.new(subject: self, predicate: "label", data: label)]
      elsif respond_to?(predicate)
        properties = send(predicate)
        properties = [] if properties == nil
        properties = [properties] if !properties.respond_to? :each
      else
        properties = []
      end
      properties.to_a.sort do |a, b|
        a.sort_value <=> b.sort_value
      end
    end

    def objekt_ids predicate
      Property.where(subject_id: id, predicate: predicate).pluck(:objekt_id)
    end

    def class_display
      if self.respond_to?(:class_from_predicate)
        classes = safe_values class_from_predicate
        unless classes.empty?
          classes.sort.join(", ")
        else
          class_internal
        end
      else
        class_internal
      end
    end

    def cardinality_of predicate
      if predicate == "label"
        1
      else
        predicates[predicate][:cardinality]
      end
    end

    def type_of predicate
      predicates[predicate][:type]
    end

    def class_of predicate
      OntologyBase.resolve_property_class(type_of(predicate))
    end

    def range_of predicate
      predicates[predicate][:range]
    end

    def singular_range_of predicate
      range = range_of predicate
      range.is_a?(Array) ? range.first : range
    end

    def inverse_of predicate
      predicates[predicate][:inverse]
    end

    def editable? predicate
      predicates[predicate][:editable]
    end

    def parse_label label
      # Wird von Subklassen überschrieben, zB in Person.
      # Dort werden anhand des Labels bestimmte Properties gesetzt.
      # Übergebe das Label als Parameter, da bei .create set_labels aufgerufen wird
      # und somit das interessante Label womöglich überschrieben wird.
    end

    # Private Instance Methods
    
    private
    
    def before_save_actions
      set_labels
      shorten_label
    end
    
    def set_labels
      self.inline_label = label
    end
    
    def shorten_label
      if label != nil
        self.label = label[0, 254]
      end
    end
  end
end
