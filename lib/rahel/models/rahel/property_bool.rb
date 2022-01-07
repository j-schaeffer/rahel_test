# Rahel: PropertyBool
# 2014-01-16 martin.stricker@gmail.com 

module Rahel
  class PropertyBool < Property
    
    # Attribute Write value
    # :bool
    # false und nil ergeben false, alles andere true (auch 0!)
    def value=(value)
      self.data_bool = value
    end
    
    # Attribute Read value
    # :bool
    def value
      data_bool
    end
    
    # Attribute Read value for Sort
    def sort_value
      if value == true
        1
      else
        0
      end
    end
    
    # Property Type
    # :bool
    def property_type
      :bool
    end
  end
end
