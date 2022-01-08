# Rahel: PropertyFloat
# 2014-01-16 martin.stricker@gmail.com 

module Rahel
  class PropertyFloat < Property
    
    # Attribute Write value
    # :float
    def value=(value)
      self.data_float = value.to_f
    end
    
    # Attribute Read value
    # :float
    def value
      data_float
    end
    
    # Property Type
    # :date
    def property_type
      :date
    end
  end
end
