# Rahel: Ontology Base Class
# 2014-02-21 martin.stricker@gmail.com

module Rahel
  class OntologyBase
    @@predicates = Hash.new { |h, k| h[k] = {} } # Default-Wert ist {} (statt nil)
    @@glass = Hash.new { |h, k| h[k] = [] } # Default-Wert ist []
    @@property_types = {
      string: Rahel::PropertyString,
      text: Rahel::PropertyText,
      integer: Rahel::PropertyInteger,
      float: Rahel::PropertyFloat,
      bool: Rahel::PropertyBool,
      date: Rahel::PropertyDate,
      objekt: Rahel::PropertyObjekt,
      url: Rahel::PropertyUrl,
      email: Rahel::PropertyEmail
    }

    # Registering Methods

    def self.register_predicate klass, predicate, type, options
      @@predicates[klass.name][predicate] = {type: type}.merge!(options)
      @@glass[klass.name] << {
        element: :predicate,
        predicate: predicate,
        type: type
      }.merge!(options)
    end

    # Information Methods

    def self.resolve_property_class type
      @@property_types[type] || Rahel::PropertyString
    end

    def self.predicates klass
      hash = {}

      # Ancestors sind alle Oberklassen und -module, in aufsteigender Reihenfolge.
      classes = [klass] + klass.ancestors

      # Wollen nur die Klassen, die von Rahel::Individual abstammen (und
      # Rahel::Individual selbst).
      rahel_classes = classes.find_all { |x| x <= Rahel::Individual }

      # Wir drehen jetzt die Reihenfolge um, damit die Oberklassen zuerst kommen.
      # So werden Predicates, die auf tieferer Ebene erneut definiert werden,
      # wieder überschrieben.
      rahel_classes.reverse!

      rahel_classes.each { |x| hash.merge! @@predicates[x.name] }
      hash
    end
    
    def self.predicates_list klass
      x = ""
      (self.predicates klass).each do |pr,d|
        x += pr + ":\n"
      end
      puts x
      nil
    end
  end
end
