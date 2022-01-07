# Rahel: Ontology Base Class
# 2014-02-21 martin.stricker@gmail.com

module Rahel
  class OntologyBase
    @@predicates = Hash.new { |h, k| h[k] = {} } # Default-Wert ist {} (statt nil)
    @@property_types = {
      string: Rahel::PropertyString,
      text: Rahel::PropertyText,
      integer: Rahel::PropertyInteger,
      float: Rahel::PropertyFloat,
      bool: Rahel::PropertyBool,
      date: Rahel::PropertyDate,
      objekt: Rahel::PropertyObjekt,
      url: Rahel::PropertyUrl,
      email: Rahel::PropertyEmail,
      phone: Rahel::PropertyPhone
    }

    # Registering Methods

    def self.register_predicate klass, predicate, type, options
      @@predicates[klass.name][predicate] = {type: type}.merge!(options)
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

    def self.creatable_types user
      Rails.application.eager_load!
      @collator = ICU::Collation::Collator.new("de")

      alphabetical = Rahel::Individual
          .descendants
          .select { |klass| klass.has_view? && !klass.weak? && user.can_create_individual?(klass) && klass.name.split("::")[0] != "Rahel" }
          .sort { |a,b| @collator.compare(I18n.t(a.name), I18n.t(b.name)) }

      tree = build_tree Rahel::Individual, user
      hierarchical = flatten_tree tree

      [alphabetical, hierarchical]
    end

    private

    def self.build_tree root, usr, lyr=0, anc=[]
      tree = root.direct_descendants

      # Rahel-Klassen rausfiltern
      while (tree.select { |klass| klass.name.split("::")[0] == "Rahel" }.any?)
        tree = tree.collect { |klass| klass.name.split("::")[0] == "Rahel" ? klass.direct_descendants : klass }.flatten
      end

      # Sortieren und in praktischen Hash überführen
      tree = tree
        .sort { |a,b| @collator.compare(I18n.t(a.name), I18n.t(b.name)) }
        .map { |klass| {klass: klass, layer: lyr, ancestors: anc, descendants: [], creatable: (klass.has_view? && !klass.weak? && usr.can_create_individual?(klass))} }

      # Rekursiv die Kindklassen zusammensuchen
      tree.each do |t|
        if t[:klass].direct_descendants.any?
          t[:descendants] = build_tree t[:klass], usr, lyr+1, anc+[t[:klass]]
        end
      end

      # Knoten die nicht erstellbar sind und keine Kindknoten haben aus dem Baum entfernen
      tree.reject! do |t|
        true unless (t[:creatable] || t[:descendants].any?)
      end

      tree
    end

    def self.flatten_tree tree
      flat = []
      tree.each do |klass|
        klass[:filter] = ([klass[:klass]] + klass[:ancestors] + klass[:klass].descendants).map{ |x| I18n.t x.name }.join
        flat += [klass]
        flat += flatten_tree(klass[:descendants]) if klass[:descendants].any?
      end
      flat
    end
  end
end
