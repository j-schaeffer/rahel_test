# 2014-06-17 marius.gawrisch@gmail.com

module Rahel
  class Glass
    def initialize controller
      @controller = controller
    end

    def humanize individual, predicate
      I18n.translate "#{individual.class.name}.#{predicate}"
    end

    #
    # INLINE
    #

    def inline individual, predicate, locals: {}
      @controller.render_to_string(
        partial: "glass/inline/property_group",
        locals: {
          individual: individual,
          predicate: predicate,
        }.merge(locals)
      ).html_safe
    end

    def inline_individual individual, locals: {}
      if individual.respond_to? "inline_template"
        @controller.render_to_string(
          partial: individual.inline_template,
          locals: { individual: individual }.merge(locals)
        ).html_safe
      else
        individual.to_s
      end
    end

    def inline_property property, locals: {}
      @controller.render_to_string(
        partial: "glass/inline/property",
        locals: { property: property }.merge(locals)
      ).html_safe
    end

    #
    # EDIT
    #

    def edit individual, predicate, locals: {}
      props = individual.get_sorted_properties_array(predicate)
      prop_class = individual.class_of(predicate)

      if props.any?
        props.map { |prop| edit_property prop }.join.html_safe
      elsif individual.cardinality_of(predicate) == 1
        # Wir müssen vielleicht etwas anzeigen, obwohl kein Property in der DB ist.

        if prop_class == PropertyObjekt && individual.editable?(predicate)
          # Es handelt sich um ein "weak"-Individual-Fall.

          # Zuerst das Individual erstellen (mit Revision)
          objekt = Individual.create(type: individual.singular_range_of(predicate))
          Revision.create_from_new_individual(objekt, @controller.current_user)

          # Nun die Property dazwischen (wieder mit Revision). (Inverse werden ggf. erstellt.)
          prop = individual.send("#{predicate}=", objekt)
          Revision.create_from_new_property(prop, @controller.current_user)
          Revision.create_from_new_property(prop.inverse, @controller.current_user) if prop.inverse
          edit_property prop
        elsif prop_class != PropertyObjekt
          # Es ist nicht Objekt, es reicht daher ein fake Property.
          prop = prop_class.new(subject: individual,
                                predicate: predicate)
          edit_property prop
        end
      end
    end

    def edit_property property, locals: {}
        @controller.render_to_string(
          partial: "glass/edit/property",
          locals: { property: property }.merge(locals)
        ).html_safe
    end

    def edit_individual individual, locals: {}
      if individual.respond_to? "edit_template"
        @controller.render_to_string(
          partial: individual.edit_template,
          locals: { individual: individual }.merge(locals)
        ).html_safe
      else
        individual.to_s
      end
    end

    #
    # NEW
    #

    def new individual, predicate
      @controller.render_to_string(
        partial: "glass/new/property",
        locals: { predicate: predicate, individual: individual }
      ).html_safe
    end
  end
end
