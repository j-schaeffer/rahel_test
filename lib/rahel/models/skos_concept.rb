# 2014-02-26 marius.gawrisch@gmail.com

module Rahel
  class SkosConcept < Individual
    property "in_scheme", :objekt, range: "Rahel::SkosConceptScheme", cardinality: 1, inverse: "has_concept"
    property "broader", :objekt, range: "Rahel::SkosConcept", inverse: "narrower"
    property "narrower", :objekt, range: "Rahel::SkosConcept", inverse: "broader"
    property "alt_label", :string
  end
end
