# 2014-02-26 marius.gawrisch@gmail.com

module Rahel
  class SkosConcept < Individual
    property "in_scheme", :objekt, range: "Rahel::SkosConceptScheme", cardinality: 1, inverse: "has_concept"
    property "broader", :objekt, range: "Rahel::SkosConcept", inverse: "narrower"
    property "narrower", :objekt, range: "Rahel::SkosConcept", inverse: "broader"
    property "alt_label", :string

    def self.hierarchical?
      joins(:broader).any?
    end

    # Gibt Array von Tripeln zurück, wo der erste Eintrag das Concept ist, der zweite Eintrag
    # der Indentierungslevel, der dritte Eintrag ein Array der broader Concepts und der vierte
    # Eintrag ein Array der narrower Concepts.
    # [
    #   [c1, 0, [c2, c3]],
    #   [c2, 1, [c1]],
    #   [c3, 1, [c1]],
    #   ...
    # ]
    def self.hierarchy active_record_relation=nil
      active_record_relation ||= all.order(:inline_label)
      alphabetical = active_record_relation
        .includes(broader: :objekt)
        .includes(narrower: :objekt)

      # Baue ein Hash auf, in dem für jedes Concept die narrower Concepts verzeichnet sind.
      # Diesen benutzen wir dann, damit wir unten nicht "self.narrower" aufrufen müssen,
      # denn dann werde neuen Individuals initialisiert, und die obigen "includes"-Klauseln
      # sind wertlos.
      hash = Hash.new { |h, k| h[k] = [] } # Default-Wert ist [] (statt nil)
      alphabetical.each do |concept|
        concept.broader.each do |broader_concept|
          hash[broader_concept.value] << concept
        end
      end

      concepts = alphabetical
        .find_all { |concept| !concept.broader.any? }
        .map { |concept| concept.hierarchy(hash) }
        .flatten(1)

      # Müssen noch die narrower Concepts sammeln. Suche dafür für jeden Eintrag die Concepts,
      # wo dieser als broader Concept eingetragen ist.
      concepts.map do |concept, level, broader|
        narrower = concepts.find_all { |_, _, broader| broader.include? concept }.map(&:first)
        [concept, level, broader, narrower]
      end
    end

    # Gibt nur Array von Tupeln der Form [property, level] zurück, da wir hier die
    # broader und narrower Concepts nicht brauchen, da wir inline nicht filtern.
    def self.property_hierarchy properties
      concept_ids = properties.map(&:objekt_id)
      concepts = hierarchy(where(id: concept_ids).order(:inline_label))
      concepts.map do |concept, level, _, _|
        property = properties.find { |prop| prop.objekt == concept }
        [property, level]
      end
    end

    def hierarchy index, level=0, broader=[]
      first = [self, level, broader]
      children = index[self]
        .sort_by(&:label)
        .map { |concept| concept.hierarchy(index, level + 1, broader + [self]) }
        .flatten(1)
      [first] + children
    end
  end
end
