# Rahel: PropertyDate
# 2014-01-16 martin.stricker@gmail.com 

module Rahel
  class PropertyDate < Property
    
    # Attribute Write value
    # :date
    # zulässig: Date, DateTime, Time, "yyyy-mm-dd" (+ Derivate), siehe Date.parse
    def value=(value)
      if (value.is_a? Date) || (value.is_a? Time) then
        pvalue = value
      else
        begin
          pvalue = Date.parse(value)
        rescue
          pvalue = 0
        end
      end
      self.data_date = pvalue
    end
    
    # Attribute Read value
    # :date
    def value
      if(data_date.is_a? Date)
        data_date
      else
        nil
      end
    end
    
    # Property Type
    # :date
    def property_type
      :date
    end
  end
end
