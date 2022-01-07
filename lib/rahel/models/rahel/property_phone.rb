# Rahel: PropertyPhone
# 2015-08-28 julian.dobmann@mailbox.org

module Rahel
  class PropertyPhone < Property
    # TODO ensure valid format for phone numbers
    validates :data, format: { with: /\A[0-9+\ ()]*\z/i,
      message: "Ungültige Telefonnummer." }

    def property_type
      :phone
    end
  end
end
