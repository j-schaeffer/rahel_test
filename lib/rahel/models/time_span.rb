# Rahel: TimeSpan
# 2014-04-17 martin.stricker@gmail.com 

module Rahel
  class TimeSpan < Individual
    property "begin", :date, cardinality: 1
    property "end", :date, cardinality: 1
    property "display_as_year", :bool, cardinality: 1, default: true
    property "time_span_label", :string, cardinality: 1
    property "is_time_span_of", :objekt, range: "Rahel::Event", inverse: "ocurred_at", cardinality: 1
  end
end
