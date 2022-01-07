# 2014-02-26 marius.gawrisch@gmail.com

module Rahel
  class SkosConceptScheme < Individual
    property "has_concept", :objekt, range: "Rahel::SkosConcept", inverse: "in_scheme"
  end
end
