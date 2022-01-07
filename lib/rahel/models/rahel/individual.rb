# Rahel: Individuals

require 'thread'
require 'timeout'

module Rahel
  class Individual < ActiveRecord::Base
    # ActiveRecord Setup
    has_many :properties, inverse_of: :subject, class_name: "Rahel::Property",
      foreign_key: :subject_id

    # Die folgende Assoziation wird zurzeit zum einen dafür verwendet, vor dem Löschen zu schauen,
    # ob dieses Individual noch mit Properties verbunden ist (in diesem Fall darf nicht
    # gelöscht werden), und zum anderen im EventManager, um diese Properties vorher zu löschen
    # (siehe auch Kommentar dort).
    has_many :is_objekt, inverse_of: :objekt, class_name: "Rahel::PropertyObjekt",
      foreign_key: :objekt_id

    # Im Label sollte schon was stehen...
    validate :non_empty_label

    # Callbacks
    before_save :before_save_actions
    before_destroy :before_destroy_actions
    around_save :handle_label_affections

    # Indizierungsmöglichkeiten bereitstellen
    extend Indexable::ClassMethods
    include Indexable::InstanceMethods

    # Klassen-Methoden "access_rule" (zum Definieren von Rechten) und "minimum_role_required"
    # (zum Abfragen von Rechten) bereitstellen
    extend Accessible

    # Das Label eines Individuals ist ja kein Property im eigentlichen Sinne, aber der Glass-Code
    # wird stark vereinfacht, wenn "label" wie ein gewöhnliches Prädikat verwendet werden kann.
    Rahel::OntologyBase.register_predicate(self, "label", :string, { cardinality: 1 })

    def self.property predicate, type, options={}

      # Names of Association & Attribute Methods & Property Class
      association_name = :"#{predicate}" # Access Property Object(s) (both)
      property_class = Rahel::OntologyBase.resolve_property_class type # Property Class (both)
      method_name_value_access = :"#{predicate}_value" # Access Property value (both)
      method_name_create_one = :"create_#{predicate}!" # Create Property (has_one)
      method_name_set_one = :"#{predicate}=" # Set or Create Property (has_one)
      method_name_add_one = :"#{predicate}=" # Add Property (has_many)

      # Available options
      range = options[:range]
      inverse = options[:inverse]
      cardinality = options[:cardinality]
      cached = options[:cached]

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
        has_one association_name, -> { where predicate: predicate }, class_name: property_class,
          foreign_key: :subject_id, dependent: :destroy

        # Accessing has_one value: individual#predicate_value
        define_method method_name_value_access do
          if cached
            # Wenn der Wert dieses Predicates gecached werden soll, dann greife hier auf den
            # Cache zu.
            send("#{association_name}_cache")
          else
            # Wenn kein Cache gewünscht ist, dann hole den Wert vom Property.
            p = send(association_name)
            p ? p.value : nil
          end
        end

        # Setting has_one value: individual#predicate=
        define_method method_name_set_one do |val=nil, set_inverse=true|
          ActiveRecord::Base.transaction(requires_new: true) do
            p = send(association_name)

            if val == nil || val == ""
              if p
                p.inverse.destroy if p.inverse
                p.destroy
              end
              
              # Save ourselves (for Callbacks etc.)
              send(association_name, true)
              save!

            else
              # Check range (raises exception if out of range)
              check_range.call(val)

              # Set value
              if p
                p.inverse.destroy if p.inverse
                p.value = val
                p.save!
              else
                p = send(method_name_create_one, value: val)
              end

              # Save ourselves (for Callbacks etc.)
              save!

              # Add/set value of inverse property if available and wanted
              val.send("#{inverse}=", self, false) if inverse && set_inverse
            end

            # Return the property, so the controller can create a revision
            p
          end
        end
      else

        # has_many
        has_many association_name, -> { where predicate: predicate }, class_name: property_class,
          foreign_key: :subject_id, dependent: :destroy

        # Accessing has_many values: individual#predicate_value
        define_method method_name_value_access do
          send(association_name).map do |p|
            p.value
          end
        end

        # Adding to has_many one value: individual#predicate=
        define_method method_name_add_one do |val=nil, set_inverse=true|
          ActiveRecord::Base.transaction(requires_new: true) do
            # Wenn das Objekt-Property ist (d.h. val ist Individual), dann checken, ob es das
            # Property schon gibt, damit keine Dublikate entstehen.
            if val.is_a? Individual
              property_exists = send(association_name).where(objekt_id: val.id).any?
            end

            if val != nil && val != "" && !property_exists
              # Check range (raises exception if out of range)
              check_range.call(val)

              # Add value
              p = send(association_name).create!(value: val)
              
              # Save ourselves (for Callbacks etc.)
              save!
              
              # Add/set value of inverse property if available and wanted
              val.send("#{inverse}=", self, false) if inverse && set_inverse

              # Return the property, so the controller can create a revision
              p
            end
          end
        end
      end
    end

    # "cached: true" heißt, dass:
    # - es wird die Methode "visible_for_value" überschrieben, so dass dort auf das Feld
    #   "visible_for_cache" aus der Indivduals-Tabelle zugegriffen wird.
    # - im before_save von Propertys mit diesem Predicate wird der Cache aktualisiert
    # (- das Datenbank-Feld muss man selber anlegen)
    # (- diese Option ist zur Zeit nur für cardinality-one-Properties implementiert)
    property "visible_for", :string, cardinality: 1, options: ["public", "member", "manager"],
      visible_for: :member, editable_for: :manager, cached: true
    property "can_be_edited_by", :objekt, range: "Person", inverse: "can_edit",
      visible_for: :member

    property "info_text", :text, editable_for: :admin, cardinality: 1
    property "internal_notes", :text, editable_for: :manager, visible_for: :manager, cardinality: 1

    # Alle dürfen erstmal alles sehen (dies kann über das "visible_for"-Property angepasst
    # werden).
    access_rule action: :view, minimum_required_role: :public

    # Jeder Member darf alles erstellen (die Sichtbarkeit wird aber vom EventManager
    # zunächst auf Members beschränkt).
    access_rule action: :create, minimum_required_role: :member

    # Alles bearbeiten und löschen dürfen nur Manager. Aber es gibt viele Fälle, in denen
    # einzelne Individuals auch von Membern bearbeitet (aber nicht gelöscht) werden dürfen,
    # zum Beispiel erhält man bei der Individual-Erstellung automatisch das Recht,
    # *diesen* Individual bearbeiten zu dürfen.
    access_rule action: [:edit, :delete], minimum_required_role: :manager

    # Diese Aktion könnte man auch "invite" nennen und dann nur bei Personen erlauben.
    # Dann müsste man aber die Berechnung der minimum_role_required ändern: Admins dürften
    # nicht mehr standardmäßig alles, denn auch Admins dürfen nicht Individuals einladen, die
    # keine Personen sind.
    access_rule action: :invite_user, minimum_required_role: :manager

    # Further Class Methods

    def self.predicates
      Rahel::OntologyBase.predicates self
    end

    def self.type_of predicate
      predicates[predicate][:type]
    end

    def self.class_of predicate
      OntologyBase.resolve_property_class(type_of(predicate))
    end

    def self.visible_for predicate
      predicates[predicate][:visible_for]
    end

    def self.editable_for predicate
      predicates[predicate][:editable_for]
    end

    # Die Optionen für ein Auswahlfeld mit vorgegebenen Werten, z.B. Person.gender
    def self.options_for predicate
      predicates[predicate][:options]
    end

    # Wird von SkosConcept überschrieben
    def self.hierarchical?
      false
    end

    def self.create options={}
      obj = super
      predicates.each do |property_name, options|
        default_value = options[:default]
        # ObjektPropertys müssen speziell behandelt werden, da sich dort
        # Default-Values auf Objekte aus der Datenbank beziehen
        if options[:type] == :objekt && options[:default].present?
          # Ein Default für eine Property wird über die descriptive_id eines Individuals
          # definiert (z.B. property "bla", ..., default: "City" )
          descriptive_id = default_value
          begin
            default_value = Individual.find_by!(descriptive_id: descriptive_id)
          rescue ActiveRecord::RecordNotFound
            # this definetly is not supposed to happen; an ontology constant is
            # missing!
            raise "While trying to create property #{property_name} of an \
              Individual of type #{self.class} an error occured: \
              Ontology constant with descriptive_id #{descriptive_id} \
              is missing; if you newly created this class or property, be sure \
              to create a migration that creates the referenced ontology \
              constant with descriptive_id #{descriptive_id}!"
          end
        end
        obj.send("#{property_name}=", default_value) if default_value != nil
      end
      obj
    end

    # Instance Methods

    def label= val
      super val.to_s.strip
    end

    def path
      "/#{type}/#{id}"
    end

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
      # Hier waere besser (Martin, Julian 2015-02-03)
      # self.predicates.has_key?(predicate)
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

    # Der Rückgabewert ist immer ein Array von Rahel::Propertys.
    # Bei cardinality: 1 enthält es 1 Element.
    # Der Unterschied zu safe_values besteht unter anderem darin, dass dort ein Array von
    # *Individuals* zurückgegeben wird.
    def sorted_properties predicate
      if predicate == "label"
        properties = [PropertyString.new(subject: self, predicate: "label", data: label)]
      elsif respond_to?(predicate)
        properties = send(predicate)
        properties = [] if properties == nil
        properties = [properties] if !properties.respond_to? :each
      else
        properties = []
      end

      if type_of(predicate) == :objekt
        properties.sort do |a, b|
          cmp = (a.objekt.class_display <=> b.objekt.class_display)
          cmp == 0 ? (a.sort_value <=> b.sort_value) : cmp
        end
      else
        properties.sort { |a, b| a.sort_value <=> b.sort_value }
      end
    end

    def sorted_visible_properties predicate, user
      sorted_properties(predicate).find_all { |prop| user.can_view_property?(prop) }
    end

    def sorted_editable_properties predicate, user
      sorted_properties(predicate).find_all { |prop| user.can_edit_property?(prop) }
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
          I18n.t type
        end
      else
        I18n.t type
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
      self.class.type_of predicate
    end

    def class_of predicate
      self.class.class_of predicate
    end

    def range_of predicate
      predicates[predicate][:range]
    end

    # Dies wird in glass.rb verwendet, wenn beim Anzeigen eines Edit-Modals abhängige Individuals
    # erstellt werden müssen. Zum Beispiel ContactPoints in SAD.
    # In Maya wird dies verwendet beim Erstellen von weak Individuals.
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

    def receives_revisions? predicate
      # TODO Was ist, wenn es das Predicate nicht gibt?
      predicates[predicate][:receives_revisions]
    end

    # Diese werden als „related strong individuals“ in die Revision mit aufgenommen.
    # Der Return-Value hat die Form: [[individual, "predicate"], ...], da das Predicate
    # bei der Revisions-Erstellung benötigt wird.
    # Achtung: Predicates mit "receives_revisions: true" müssen "cardinality: 1" sein und
    # ein Reverse Property haben.
    # Außerdem wird ein weak Individual gelöscht, wenn es keine Revision-Receivers mehr hat
    # (tritt bei einer vom EventManager kontrollierten Lösch-Kaskade auf).
    # (Diese Methode könnte auch "owners" heißen.)
    def revision_receivers
      predicates
        .select { |_, options| options[:receives_revisions] }
        .map    { |predicate, _| send(predicate) }
        .reject { |property| property.nil? }
        .map    { |property| [property.value, (property.inverse.predicate rescue nil)] }
        .reject { |individual, _| individual.nil? }
      # possible optimisation: nur die Ids holen
    end

    def parse_label label
      # Wird von Subklassen überschrieben, zB in Person (in SAD).
      # Dort werden anhand des Labels bestimmte Properties gesetzt.
      # Übergebe das Label als Parameter, da bei .create set_labels aufgerufen wird
      # und somit das interessante Label womöglich überschrieben wird.
    end

    # Diese Methode soll in den Subklassen überschrieben werden.
    # Man könnte darüber nachdenken, statt dem Überschreiben eine Klassen-Methode wie
    # "property" und "access_rule" einzurichten, mit der man angeben kann, ob die entsprechende
    # Klasse weak ist.
    def self.weak?
      false
    end

    def weak?
      self.class.weak?
    end

    # Diese Methode soll ggf. in den Subklassen überschrieben werden.
    # Klassen ohne View sollen nicht in den Suchindex aufgenommen werden.
    def self.has_view?
      true
    end

    def has_view?
      self.class.has_view?
    end

    def computed_label?
      false
    end

    # Marius: Ich habe das hier reingeschrieben, weil die Methode in Rahel::User aufgerufen
    # wird. In der Praxis wird der Call nie hier ankommen, weil die Methode in Maya::Person
    # implementiert ist. Aber falls jemand anders eine andere Anwendung als Maya auf Rahel
    # aufbauen sollte, dann ist es gut, wenn es keine Exception gibt, auch wenn die Methode
    # in (der Entsprechung von) Person noch nicht implementiert wurde.
    def automatically_editable
      []
    end
    
    # Public: Get all Persons that are allowed to edit this Individual, granted 
    # by implicit edit rights. Subclasses of Individual may define their own
    # implicit edit rights by overriding this Method.
    #
    # Returns an unsorted Array of Person Objects.
    def automatically_editable_by
      []
    end

    # Index Value
    # Der Wert, der benutzt wird, wenn das Individual im Suchtextfeld eines anderen vorkommt.
    def index_value
      label
    end

    # Facet Value
    # Der Wert, der benutzt wird, wenn das Individual in einer Facette eines anderen vorkommt.
    def facet_value
      label
    end

    # Gibt die Mindest-Rolle zurück, die man haben muss, um dieses Individual anzuschauen.
    # TODO Finde Namen, der es besser von "visibile_for" und "minimum_required_role(:view)"
    # abgerenzt und deutlich macht, dass diese Methode hier die beiden anderen "verrrechnet".
    def visibility
      # Achtung: Nun ist diese Logik zwei Mal implementiert, einmal hier und einmal in
      # User#can?. Man könnte in User#can? auf diese Methode hier zurückgreifen, aber dann
      # kann man dort nicht mehr auf einen Blick sehen, wie die Rechte-Logik aussieht.
      (visible_for_value || self.class.minimum_role_required(:view)).to_sym
    end

    # Private Instance Methods
    
    private

    def non_empty_label
      # Bin mir nicht sicher ob es Probleme geben könnte, falls Weak-Indis
      # zwischengespeichert werden mit einem leeren Label. Diese also
      # vorsichtshalber ignorieren.
      unless weak? || (label && label.size > 1)
        errors.add(:label, "Die Bezeichnung muss mehr als ein Zeichen enthalten.")
      end
    end
    
    def before_save_actions
      set_labels
      shorten_label
    end

    def handle_label_affections
      # Speichere alle Individuals, deren Label von uns abhängt.
      # Allerdings nur, falls sich unser eigenes Label geändert hat.
      # ACHTUNG: Es ist nirgendwo festgelegt, dass bei Objekt-Properties
      # mit :affects_label = true sich nur das Label des Objekt-Individuals
      # auf das Label des Subject-Individuals auswirkt.
      # Im Moment ist dies der Fall, sollte sich das ändern, muss der Code
      # an dieser Stelle darauf angepasst werden.
      label_changed = label_changed?

      yield

      if label_changed
        Thread.new(id) do |idt|
          File.open(Rails.root.join("tmp","label_affection.lock"), File::RDWR|File::CREAT, 0644) do |f|
            begin
              # Auf Lockfile warten
              Timeout::timeout(5*60) { f.flock(File::LOCK_EX) }
            rescue Timeout::Error => e
              Logger.new("log/label_affection.log").warning("Couldn't acquire exclusive lock (Timeout of 5 min reached)")
            else
              # Connection Pool um verwaiste Verbindungen zu verhindern:
              # https://bibwild.wordpress.com/2014/07/17/activerecord-concurrency-in-rails4-avoid-leaked-connections/
              ActiveRecord::Base.connection_pool.with_connection do |con|
                Individual.find(idt).is_objekt
                  .includes(:subject)
                  .find_all { |prop| prop.subject.predicates[prop.predicate][:affects_label] }
                  .each { |x| x.subject.save }
              end
            end
          end
        end
      end
    end

    def set_labels
      self.inline_label = label
    end

    def shorten_label
      if label != nil
        self.label = label[0, 254]
      end
    end

    # Habe das "_actions" genannt, um analog zu "before_save_actions" zu sein. Aber da hier ja
    # gar keine Actions passieren, vielleicht umbenennen?
    def before_destroy_actions
      if properties(reload: true).any? || is_objekt(reload: true).any?
        # Wenn man hier false zurückgibt, dann wird das löschen nicht durchgefürt. Stattdessen
        # gibt indi.destroy false zurück.
        false
      end
    
      # prevent deletion of Ontology Constants
      if descriptive_id.present?
        raise ErrorController::UndeletableIndividual, "This Individual '#{self.label}'(#{self.id}) is an ontology constant as indicated by its non-empty descriptive_id value '#{self.descriptive_id}' and thus must not be deleted."
      end
    end
  end
end
