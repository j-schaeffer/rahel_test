# Rahel: TimeSpan
# 2014-04-17 martin.stricker@gmail.com 

module Rahel
  class TimeSpan < Individual
    property "begin", :date, cardinality: 1, affects_label: true
    property "end", :date, cardinality: 1, affects_label: true
    property "display_as_year", :bool, cardinality: 1, default: false, affects_label: true
    property "time_span_label", :string, cardinality: 1
    property "is_time_span_of", :objekt, range: "Rahel::Event", inverse: "ocurred_at", cardinality: 1

    validate :begin_before_end_date

    def begin_before_end_date
      if begin_value.is_a?(Date) && end_value.is_a?(Date) && begin_value > end_value
        errors.add(:end, "Enddatum darf nicht vor dem Startdatum liegen.")
      end
    end
  end
end
