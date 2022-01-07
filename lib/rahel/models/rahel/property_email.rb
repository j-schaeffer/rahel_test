# Rahel: PropertyEmail
# 2014-03-31 martin.stricker@gmail.com 

module Rahel
  class PropertyEmail < Property
    # ensure valid format for email addresses in database, strict == raise exception
    validates :data, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i,
      message: "Ungültige E-Mail-Adresse." }
    
    # Property Type
    # :email
    def property_type
      :email
    end
  end
end
