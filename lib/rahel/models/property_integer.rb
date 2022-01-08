# Rahel: PropertyInteger
# 2014-01-16 martin.stricker@gmail.com 

module Rahel
  class PropertyInteger < Property
    
    # Attribute Write value
    # :integer
    def value=(value)
      self.data_int = value.to_i
    end
    
    # Attribute Read value
    # :integer
    def value
      data_int
    end
    
    # Property Type
    # :integer
    def property_type
      :integer
    end
  end
end
