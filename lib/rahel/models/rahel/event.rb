# Rahel: Event
# 2014-01-16 martin.stricker@gmail.com 

module Rahel
  class Event < Individual
    property "ocurred_at", :objekt, range: "Rahel::TimeSpan", inverse: "is_time_span_of", cardinality: 1
  end
end
