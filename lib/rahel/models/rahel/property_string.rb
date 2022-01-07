# Rahel: PropertyString
# 2014-01-15 martin.stricker@gmail.com 

module Rahel
  class PropertyString < Property
    validates :data, length: { maximum: 500 }
    
    # Property Type
    # :string
    def property_type
      :string
    end
  end
end
